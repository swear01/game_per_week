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
    private const int RemoveCount = 3;

    private sealed record PendingSelection(Player Owner, IReadOnlyList<CardModel> Cards);

    private static readonly object PendingGate = new();
    private static PendingSelection? _pending;

    public static bool TryDefer(PreservedFog relic, out Exception? failure)
    {
        failure = null;
        var owner = relic.Owner;
        var runManager = RunManager.Instance;
        if (owner == null
            || runManager == null
            || runManager.NetService.Type != NetGameType.Singleplayer
            || NRun.Instance != null
            || !owner.Relics.Any(r => r is VakuuContract))
        {
            return false;
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
        if (cards.Count < RemoveCount)
        {
            failure = new InvalidOperationException($"Preserved Fog found only {cards.Count} removable starting cards.");
            return true;
        }

        var seenCards = new HashSet<CardModel>(ReferenceEqualityComparer.Instance);
        if (cards.Any(card => !seenCards.Add(card)))
        {
            failure = new InvalidOperationException("Preserved Fog starting deck contains duplicate card references.");
            return true;
        }

        var pending = new PendingSelection(owner, cards);
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
        GD.Print($"[VakuuPlayer] Preserved Fog startup effect deferred until AfterActEntered (snapshot={cards.Count})");
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
        if (NRun.Instance == null)
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

        lock (PendingGate)
        {
            if (!ReferenceEquals(_pending, pending))
            {
                return;
            }
            _pending = null;
        }

        var map = NMapScreen.Instance;
        var reopenMap = map?.IsOpen == true;

        try
        {
            if (reopenMap)
            {
                map!.Close(false);
            }

            GD.Print("[VakuuPlayer] opening deferred Preserved Fog selection");
            var snapshotIndex = new Dictionary<CardModel, int>(ReferenceEqualityComparer.Instance);
            for (var index = 0; index < pending.Cards.Count; index++)
            {
                snapshotIndex.TryAdd(pending.Cards[index], index);
            }
            var prefs = new CardSelectorPrefs(CardSelectorPrefs.RemoveSelectionPrompt, RemoveCount);
            var selectionResult = await CardSelectCmd.FromDeckGeneric(
                owner,
                prefs,
                card => card.IsRemovable && snapshotIndex.ContainsKey(card),
                card => snapshotIndex.TryGetValue(card, out var index) ? index : int.MaxValue);
            if (NRun.Instance == null)
            {
                GD.PrintErr("[VakuuPlayer] Preserved Fog selection ended after the run was closed; skipping deck mutation.");
                return;
            }
            if (selectionResult == null)
            {
                throw new InvalidOperationException("Preserved Fog card selection returned null.");
            }

            var selected = selectionResult.ToList();
            if (selected.Count != RemoveCount)
            {
                throw new InvalidOperationException($"Preserved Fog selected {selected.Count} cards instead of {RemoveCount}.");
            }

            var selectedSet = new HashSet<CardModel>(selected, ReferenceEqualityComparer.Instance);
            if (selectedSet.Count != RemoveCount)
            {
                throw new InvalidOperationException("Preserved Fog selection contains duplicate card references.");
            }
            var currentDeck = PileTypeExtensions.GetPile(PileType.Deck, owner);
            if (currentDeck == null || selected.Any(card => !card.IsRemovable || !currentDeck.Cards.Contains(card, ReferenceEqualityComparer.Instance)))
            {
                throw new InvalidOperationException("Preserved Fog selection cards are no longer available in the deck.");
            }

            foreach (var card in selected)
            {
                if (NRun.Instance == null)
                {
                    GD.PrintErr("[VakuuPlayer] Preserved Fog run ended during deck mutation; stopping safely.");
                    return;
                }
                await CardPileCmd.RemoveFromDeck(card, true);
            }

            if (NRun.Instance == null)
            {
                GD.PrintErr("[VakuuPlayer] Preserved Fog run ended before adding Folly; stopping safely.");
                return;
            }
            await CardPileCmd.AddCurseToDeck<Folly>(owner);
            GD.Print($"[VakuuPlayer] Preserved Fog removed cards: {string.Join(", ", selected.Select(c => c.Id.Entry))}");
        }
        finally
        {
            if (reopenMap && NRun.Instance != null && NMapScreen.Instance != null)
            {
                NMapScreen.Instance.Open(true);
            }
        }
    }
}
