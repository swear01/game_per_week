using System.Collections;
using UnityEngine;
using StreetCardBrawler;
using StreetCardBrawler.Cards;

namespace StreetCardBrawler.Combat
{
    public sealed class CardEffectResolver : MonoBehaviour
    {
        public PlayerFighter player;
        public EnemyFighter enemy;
        public BattleUIController ui;

        public void Resolve(CardData card)
        {
            if (card == null || player == null || enemy == null) return;
            StartCoroutine(ResolveRoutine(card));
        }

        private IEnumerator ResolveRoutine(CardData card)
        {
            if (card.windup > 0f)
            {
                ui.ShowStatus(card.cardName + "...");
                yield return new WaitForSeconds(card.windup);
            }

            switch (card.effectType)
            {
                case CardEffectType.Damage:
                    TryDealDamage(card);
                    break;
                case CardEffectType.Block:
                    player.ApplyBlock(card.blockDuration, card.blockMultiplier);
                    ui.ShowStatus("Blocked up");
                    break;
                case CardEffectType.DashDamage:
                    player.DashForward(card.dashDistance);
                    TryDealDamage(card);
                    break;
                case CardEffectType.Taunt:
                    player.AddEnergy(card.energyGain);
                    enemy.ApplyTaunt(card.tauntDuration);
                    ui.ShowStatus("Taunt: energy up, enemy angry");
                    break;
            }
        }

        private void TryDealDamage(CardData card)
        {
            float distance = Mathf.Abs(enemy.transform.position.x - player.transform.position.x);
            if (distance <= card.range)
            {
                enemy.TakeDamage(card.damage);
                ui.ShowStatus(card.cardName + " hit");
            }
            else
            {
                ui.ShowStatus(card.cardName + " missed");
            }
        }
    }
}
