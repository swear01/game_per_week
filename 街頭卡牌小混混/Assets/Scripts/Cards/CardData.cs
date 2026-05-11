using UnityEngine;

namespace StreetCardBrawler.Cards
{
    public enum CardEffectType
    {
        Damage,
        Block,
        DashDamage,
        Taunt
    }

    [CreateAssetMenu(menuName = "Street Card Brawler/Card Data")]
    public sealed class CardData : ScriptableObject
    {
        public string cardName = "New Card";
        [TextArea] public string description = "Card description";
        public CardEffectType effectType = CardEffectType.Damage;
        public int energyCost = 1;
        public int damage = 5;
        public float range = 1.5f;
        public float windup = 0f;
        public float blockDuration = 1.5f;
        public float blockMultiplier = 0.35f;
        public float dashDistance = 2.2f;
        public int energyGain = 0;
        public float tauntDuration = 3f;
    }
}
