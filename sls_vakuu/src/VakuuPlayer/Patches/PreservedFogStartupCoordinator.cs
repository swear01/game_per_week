using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Godot;
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

        var pending = new PendingSelection(owner, cards);
        var previous = Interlocked.Exchange(ref _pending, pending);
        if (previous != null && ReferenceEquals(previous.Owner, owner))
        {
            Interlocked.CompareExchange(ref _pending, null, pending);
            failure = new InvalidOperationException("Preserved Fog startup selection was deferred more than once for the same run.");
            return true;
        }
        if (previous != null)
        {
            GD.Print("[VakuuPlayer] discarded an abandoned Preserved Fog startup selection");
        }
        GD.Print($"[VakuuPlayer] Preserved Fog startup effect deferred until AfterActEntered (snapshot={cards.Count})");
        return true;
    }

    public static async Task ApplyPendingAsync(Player owner)
    {
        var pending = Volatile.Read(ref _pending);
        if (pending == null)
        {
            return;
        }
        if (!ReferenceEquals(pending.Owner, owner))
        {
            Interlocked.CompareExchange(ref _pending, null, pending);
            return;
        }
        if (Interlocked.CompareExchange(ref _pending, null, pending) != pending)
        {
            return;
        }

        if (NRun.Instance == null)
        {
            throw new InvalidOperationException("NRun is not available for the deferred Preserved Fog selection.");
        }

        var map = NMapScreen.Instance;
        var reopenMap = map?.IsOpen == true;
        if (reopenMap)
        {
            map!.Close(false);
        }

        try
        {
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
            if (selectionResult == null)
            {
                throw new InvalidOperationException("Preserved Fog card selection returned null.");
            }

            var selected = selectionResult.ToList();
            if (selected.Count != RemoveCount)
            {
                throw new InvalidOperationException($"Preserved Fog selected {selected.Count} cards instead of {RemoveCount}.");
            }

            foreach (var card in selected)
            {
                await CardPileCmd.RemoveFromDeck(card, true);
            }

            await CardPileCmd.AddCurseToDeck<Folly>(owner);
            GD.Print($"[VakuuPlayer] Preserved Fog removed cards: {string.Join(", ", selected.Select(c => c.Id.Entry))}");
        }
        finally
        {
            if (reopenMap && NMapScreen.Instance != null)
            {
                NMapScreen.Instance.Open(true);
            }
        }
    }
}
