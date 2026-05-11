using UnityEngine;
using StreetCardBrawler.Combat;

namespace StreetCardBrawler
{
    public sealed class CardButtonBinder : MonoBehaviour
    {
        public CardDeckController deck;
        public int handIndex;

        public void Play()
        {
            if (deck != null)
            {
                deck.TryPlayCard(handIndex);
            }
        }
    }
}
