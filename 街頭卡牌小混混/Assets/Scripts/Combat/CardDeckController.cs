using System.Collections.Generic;
using UnityEngine;
using StreetCardBrawler;
using StreetCardBrawler.Cards;

namespace StreetCardBrawler.Combat
{
    public sealed class CardDeckController : MonoBehaviour
    {
        public List<CardData> deck = new List<CardData>();
        public int handSize = 3;
        public CardEffectResolver resolver;
        public BattleUIController ui;

        private readonly List<CardData> hand = new List<CardData>();
        private int drawIndex;
        private bool battleOver;

        public IReadOnlyList<CardData> Hand => hand;

        private void Start()
        {
            DrawOpeningHand();
        }

        public void SetBattleOver(bool value)
        {
            battleOver = value;
        }

        public void TryPlayCard(int handIndex)
        {
            if (battleOver || handIndex < 0 || handIndex >= hand.Count) return;

            CardData card = hand[handIndex];
            if (card == null) return;

            if (!resolver.player.SpendEnergy(card.energyCost))
            {
                ui.ShowStatus("Not enough energy");
                return;
            }

            resolver.Resolve(card);
            hand[handIndex] = DrawCard();
            ui.Refresh();
        }

        private void DrawOpeningHand()
        {
            hand.Clear();
            for (int i = 0; i < handSize; i++)
            {
                hand.Add(DrawCard());
            }
            ui.Refresh();
        }

        private CardData DrawCard()
        {
            if (deck.Count == 0) return null;
            CardData card = deck[drawIndex % deck.Count];
            drawIndex++;
            return card;
        }
    }
}
