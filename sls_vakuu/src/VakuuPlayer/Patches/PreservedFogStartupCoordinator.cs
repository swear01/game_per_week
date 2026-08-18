using System.Linq;
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
    private sealed record PendingSelection(Player Owner, IReadOnlyList<CardModel> Cards);

    private static PendingSelection? _pending;

    public static bool TryDefer(PreservedFog relic)
    {
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

        var cards = PileTypeExtensions.GetPile(PileType.Deck, owner).Cards
            .Where(card => card.IsRemovable)
            .ToList();
        if (cards.Count < 3)
        {
            throw new InvalidOperationException($"Preserved Fog found only {cards.Count} removable starting cards.");
        }

        _pending = new PendingSelection(owner, cards);
        GD.Print($"[VakuuPlayer] Preserved Fog startup effect deferred until AfterActEntered (snapshot={cards.Count})");
        return true;
    }

    public static async Task ApplyPendingAsync(Player owner)
    {
        var pending = _pending;
        if (pending == null || !ReferenceEquals(pending.Owner, owner))
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
            var snapshotIndex = pending.Cards
                .Select((card, index) => (card, index))
                .ToDictionary(item => item.card, item => item.index);
            var prefs = new CardSelectorPrefs(CardSelectorPrefs.RemoveSelectionPrompt, 3);
            var selected = (await CardSelectCmd.FromDeckGeneric(
                owner,
                prefs,
                card => card.IsRemovable && snapshotIndex.ContainsKey(card),
                card => snapshotIndex[card])).ToList();
            if (selected.Count != 3)
            {
                throw new InvalidOperationException($"Preserved Fog selected {selected.Count} cards instead of 3.");
            }

            foreach (var card in selected)
            {
                await CardPileCmd.RemoveFromDeck(card, true);
            }

            await CardPileCmd.AddCurseToDeck<Folly>(owner);
            GD.Print($"[VakuuPlayer] Preserved Fog removed cards: {string.Join(", ", selected.Select(c => c.Id.Entry))}");
            _pending = null;
        }
        finally
        {
            _pending = null;
            if (reopenMap && NMapScreen.Instance != null)
            {
                NMapScreen.Instance.Open(true);
            }
        }
    }
}
