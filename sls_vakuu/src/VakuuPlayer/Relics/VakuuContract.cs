using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MegaCrit.Sts2.Core.Combat;
using MegaCrit.Sts2.Core.Commands;
using MegaCrit.Sts2.Core.Entities.Cards;
using MegaCrit.Sts2.Core.Entities.Creatures;
using MegaCrit.Sts2.Core.Entities.Players;
using MegaCrit.Sts2.Core.Entities.Relics;
using MegaCrit.Sts2.Core.GameActions.Multiplayer;
using MegaCrit.Sts2.Core.HoverTips;
using MegaCrit.Sts2.Core.Localization;
using MegaCrit.Sts2.Core.Localization.DynamicVars;
using MegaCrit.Sts2.Core.Models;
using MegaCrit.Sts2.Core.Models.Relics;
using MegaCrit.Sts2.Core.Nodes.Vfx;
using MegaCrit.Sts2.Core.Random;
using MegaCrit.Sts2.Core.ValueProps;

namespace VakuuPlayer.Relics;

/// <summary>
/// 瓦庫契約：取代低語耳環。每回合開始由瓦庫接管，從左到右自動打牌
/// （最多 13 張 / 沒牌 / 沒能量 / 玩家結束回合），打完控制權歸還，之後才能用藥水等。
/// 邏輯為低語耳環 AfterAutoPrePlayPhaseEnteredLate 的複製（去掉第一回合限制）。
/// </summary>
public sealed class VakuuContract : RelicModel
{
    public const int MaxCardsToPlay = 13;

    public override RelicRarity Rarity => RelicRarity.Ancient;

    protected override string IconBaseName => "whispering_earring";

    public override decimal ModifyMaxEnergy(Player player, decimal amount)
    {
        return player != Owner ? amount : amount + DynamicVars.Energy.BaseValue;
    }

    protected override IEnumerable<DynamicVar> CanonicalVars =>
    [
        new EnergyVar(1)
    ];

    protected override IEnumerable<IHoverTip> ExtraHoverTips =>
    [
        HoverTipFactory.ForEnergy(this)
    ];

    public override async Task AfterAutoPrePlayPhaseEnteredLate(PlayerChoiceContext choiceContext, Player player)
    {
        var owner = Owner;
        if (owner == null || player != owner)
        {
            return;
        }

        var combatState = player.Creature.CombatState;
        var playerCombatState = owner.PlayerCombatState;
        if (combatState == null || playerCombatState == null)
        {
            return;
        }

        Flash();

        using var _ = CardSelectCmd.PushSelector(new VakuuCardSelector(), false);

        var cardsPlayed = 0;
        var startTurn = playerCombatState.TurnNumber;
        while (cardsPlayed < MaxCardsToPlay
               && !CombatManager.Instance.IsOverOrEnding
               && !CombatManager.Instance.IsPlayerReadyToEndTurn(player)
               && playerCombatState.TurnNumber == startTurn)
        {
            var handPile = PileTypeExtensions.GetPile(PileType.Hand, owner);
            if (handPile == null)
            {
                break;
            }

            var card = handPile.Cards.FirstOrDefault(c => c.CanPlay());
            if (card == null)
            {
                break;
            }

            var target = GetTarget(card, combatState, owner);
            await card.SpendResources();
            await CardCmd.AutoPlay(choiceContext, card, target, AutoPlayType.Default, true, false);
            cardsPlayed++;
        }

        if (cardsPlayed == 0)
        {
            return;
        }

        var line = cardsPlayed >= MaxCardsToPlay
            ? "WHISPERING_EARRING.warning"
            : "WHISPERING_EARRING.approval";
        TalkCmd.Play(new LocString("relics", line), owner.Creature, VfxColor.Purple, VfxDuration.Custom);
    }

    /// <summary>選目標：敵人 = 最左邊；友方 = 隨機；自己 = 玩家。</summary>
    private Creature? GetTarget(CardModel card, ICombatState combatState, Player owner)
    {
        var combatTargets = owner.RunState.Rng.CombatTargets;
        switch (card.TargetType)
        {
            case TargetType.AnyEnemy:
                return combatState.HittableEnemies.FirstOrDefault();
            case TargetType.AnyAlly:
                return combatTargets.NextItem(combatState.Allies.Where(c => c != null && c.IsAlive && c.IsPlayer && c != owner.Creature));
            case TargetType.AnyPlayer:
                return owner.Creature;
            default:
                return null;
        }
    }
}
