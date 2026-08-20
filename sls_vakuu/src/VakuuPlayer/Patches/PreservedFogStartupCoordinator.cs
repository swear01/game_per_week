using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Godot;
using HarmonyLib;
using MegaCrit.Sts2.Core.CardSelection;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Cards;
using MegaCrit.Sts2.Core.Models.Relics;
using MegaCrit.Sts2.Core.Multiplayer.Game;
using MegaCrit.Sts2.Core.Nodes;
using MegaCrit.Sts2.Core.Nodes.Screens.Map;
using MegaCrit.Sts2.Core.Runs;
using VakuuPlayer.Relics;

namespace VakuuPlayer.Patches;

internal static class PreservedFogStartupCoordinator
{
    private sealed record PendingSelection(Player Owner, IReadOnlyList<CardModel> Cards, int RemoveCount);

    private static readonly object PendingGate = new();
    private static PendingSelection? _pending;

    /// <remarks>
    /// A return value of true means the patch handled the vanilla callback. Callers must surface
    /// a non-null failure because the deferred effect could not be scheduled safely.
    /// </remarks>
    public static bool TryDefer(PreservedFog relic, out Exception? failure)
    {
        failure = null;
        var owner = relic.Owner;
        var runManager = RunManager.Instance;
        if (owner == null
            || runManager == null
            || runManager.NetService == null
            || runManager.NetService.Type != NetGameType.Singleplayer
            || NRun.Instance != null
            || !owner.Relics.Any(r => r is VakuuContract))
        {
            return false;
        }

        var removeCount = relic.DynamicVars.TryGetValue("Cards", out var cardsVar)
            ? cardsVar.IntValue
            : 0;
        if (removeCount <= 0)
        {
            failure = new InvalidOperationException($"Preserved Fog removal count was invalid: {removeCount}.");
            return true;
        }

        var deckPile = PileTypeExtensions.GetPile(PileType.Deck, owner);
        if (deckPile == null)
        {
            failure = new InvalidOperationException("Player deck pile is not initialized during Preserved Fog startup.");
            return true;
        }

        var cards = deckPile.Cards
            .Where(card => card.IsRemovable)
            .ToList();
        if (cards.Count < removeCount)
        {
            failure = new InvalidOperationException($"Preserved Fog found only {cards.Count} removable starting cards; {removeCount} required.");
            return true;
        }

        var seenCards = new HashSet<CardModel>(ReferenceEqualityComparer.Instance);
        if (cards.Any(card => !seenCards.Add(card)))
        {
            failure = new InvalidOperationException("Preserved Fog starting deck contains duplicate card references.");
            return true;
        }

        var pending = new PendingSelection(owner, cards, removeCount);
        PendingSelection? previous;
        lock (PendingGate)
        {
            previous = _pending;
            if (previous != null && ReferenceEquals(previous.Owner, owner))
            {
                failure = new InvalidOperationException("Preserved Fog startup selection was deferred more than once for the same run.");
                return true;
            }
            _pending = pending;
        }
        if (previous != null)
        {
            GD.Print("[VakuuPlayer] discarded an abandoned Preserved Fog startup selection");
        }
        GD.Print($"[VakuuPlayer] Preserved Fog startup effect deferred until AfterActEntered (removable={cards.Count}/deck={deckPile.Cards.Count})");
        return true;
    }

    private static void ClearPending(PendingSelection pending)
    {
        lock (PendingGate)
        {
            if (ReferenceEquals(_pending, pending))
            {
                _pending = null;
            }
        }
    }

    private static void ClearPending()
    {
        lock (PendingGate)
        {
            _pending = null;
        }
    }

    [HarmonyPatch(typeof(RunManager), nameof(RunManager.OnEnded))]
    private static class RunEndPatch
    {
        private static void Prefix() => ClearPending();
    }

    public static async Task ApplyPendingAsync(Player owner)
    {
        PendingSelection? pending;
        lock (PendingGate)
        {
            pending = _pending;
        }
        if (pending == null)
        {
            return;
        }
        if (!ReferenceEquals(pending.Owner, owner))
        {
            ClearPending(pending);
            return;
        }
        var run = NRun.Instance;
        if (run == null)
        {
            ClearPending(pending);
            throw new InvalidOperationException("NRun is not available for the deferred Preserved Fog selection.");
        }

        var deckPile = PileTypeExtensions.GetPile(PileType.Deck, owner);
        if (deckPile == null)
        {
            ClearPending(pending);
            throw new InvalidOperationException("Player deck pile is not initialized for the deferred Preserved Fog selection.");
        }

        var liveCards = new HashSet<CardModel>(deckPile.Cards, ReferenceEqualityComparer.Instance);
        var unavailable = pending.Cards
            .Where(card => !card.IsRemovable || !liveCards.Contains(card))
            .Select(card => card.Id.Entry)
            .ToList();
        if (unavailable.Count > 0)
        {
            ClearPending(pending);
            throw new InvalidOperationException($"Preserved Fog snapshot cards are no longer removable: {string.Join(", ", unavailable)}");
        }

        var map = NMapScreen.Instance;
        var reopenMap = map?.IsOpen == true;

        try
        {
            if (reopenMap)
            {
                map!.Close(false);
            }

            lock (PendingGate)
            {
                if (!ReferenceEquals(_pending, pending))
                {
                    return;
                }
                _pending = null;
            }

            GD.Print("[VakuuPlayer] opening deferred Preserved Fog selection");
            var snapshotIndex = new Dictionary<CardModel, int>(ReferenceEqualityComparer.Instance);
            for (var index = 0; index < pending.Cards.Count; index++)
            {
                snapshotIndex.TryAdd(pending.Cards[index], index);
            }
            var prefs = new CardSelectorPrefs(CardSelectorPrefs.RemoveSelectionPrompt, pending.RemoveCount);
            var selectionResult = await CardSelectCmd.FromDeckGeneric(
                owner,
                prefs,
                card => card.IsRemovable && snapshotIndex.ContainsKey(card),
                card => snapshotIndex.TryGetValue(card, out var index) ? index : int.MaxValue);
            if (!ReferenceEquals(NRun.Instance, run))
            {
                GD.PrintErr("[VakuuPlayer] Preserved Fog selection ended after the original run was closed; skipping deck mutation.");
                return;
            }
            if (selectionResult == null)
            {
                throw new InvalidOperationException("Preserved Fog card selection was cancelled.");
            }

            var selected = selectionResult.ToList();
            if (selected.Count != pending.RemoveCount)
            {
                throw new InvalidOperationException($"Preserved Fog selected {selected.Count} cards instead of {pending.RemoveCount}.");
            }

            var selectedSet = new HashSet<CardModel>(selected, ReferenceEqualityComparer.Instance);
            if (selectedSet.Count != pending.RemoveCount)
            {
                throw new InvalidOperationException("Preserved Fog selection contains duplicate card references.");
            }
            var currentDeck = PileTypeExtensions.GetPile(PileType.Deck, owner);
            if (currentDeck == null || selected.Any(card => !card.IsRemovable || !currentDeck.Cards.Contains(card, ReferenceEqualityComparer.Instance)))
            {
                throw new InvalidOperationException("Preserved Fog selection cards are no longer available in the deck.");
            }

            var removedCount = 0;
            try
            {
                foreach (var card in selected)
                {
                    if (!ReferenceEquals(NRun.Instance, run))
                    {
                        GD.PrintErr("[VakuuPlayer] Preserved Fog original run ended during deck mutation; stopping safely.");
                        return;
                    }
                    await CardPileCmd.RemoveFromDeck(card, true);
                    if (!ReferenceEquals(NRun.Instance, run))
                    {
                        GD.PrintErr($"[VakuuPlayer] Preserved Fog original run ended after removing {removedCount + 1}/{selected.Count} cards.");
                        return;
                    }
                    removedCount++;
                }

                if (!ReferenceEquals(NRun.Instance, run))
                {
                    GD.PrintErr("[VakuuPlayer] Preserved Fog original run ended before adding Folly; stopping safely.");
                    return;
                }
                await CardPileCmd.AddCurseToDeck<Folly>(owner);
                if (!ReferenceEquals(NRun.Instance, run))
                {
                    GD.PrintErr("[VakuuPlayer] Preserved Fog original run ended after adding Folly.");
                    return;
                }
                GD.Print($"[VakuuPlayer] Preserved Fog removed cards: {string.Join(", ", selected.Select(c => c.Id.Entry))}");
            }
            catch (Exception e)
            {
                GD.PrintErr($"[VakuuPlayer] Preserved Fog deck mutation failed after removing {removedCount}/{selected.Count} cards: {e}");
                throw;
            }
        }
        finally
        {
            if (reopenMap && ReferenceEquals(NRun.Instance, run) && NMapScreen.Instance is { IsOpen: false } currentMap)
            {
                try
                {
                    currentMap.Open(true);
                }
                catch (Exception e)
                {
                    GD.PrintErr($"[VakuuPlayer] failed to reopen map after Preserved Fog selection: {e}");
                }
            }
        }
    }
}
