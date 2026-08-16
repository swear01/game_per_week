using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using HarmonyLib;
using MegaCrit.Sts2.Core.Models.Relics;

namespace VakuuPlayer.Patches;

/// <summary>
/// 低語耳環（WhisperingEarring）：原版只接管第一回合（TurnNumber &lt;= 1）。
/// Transpiler 把接管條件跳轉（ble.s）改成無條件跳轉（br.s）→ 瓦庫接管每一回合。
/// </summary>
[HarmonyPatch]
public static class EveryTurnTakeoverPatch
{
    private static MethodBase TargetMethod()
    {
        var stateMachine = AccessTools.FirstInner(typeof(WhisperingEarring),
            t => t.Name.Contains("AfterAutoPrePlayPhaseEnteredLate"));
        return AccessTools.Method(stateMachine, "MoveNext")
               ?? throw new MissingMethodException("WhisperingEarring takeover state machine MoveNext not found");
    }

    private static IEnumerable<CodeInstruction> Transpiler(IEnumerable<CodeInstruction> instructions)
    {
        var codes = instructions.ToList();
        for (int i = 0; i < codes.Count - 2; i++)
        {
            // 模式：callvirt get_TurnNumber ; ldc.i4.1 ; ble(.s) IL_接管體
            if (codes[i].opcode == OpCodes.Callvirt
                && codes[i].operand is MethodInfo m
                && m.Name == "get_TurnNumber"
                && m.DeclaringType?.Name == "PlayerCombatState"
                && codes[i + 1].opcode == OpCodes.Ldc_I4_1
                && (codes[i + 2].opcode == OpCodes.Ble || codes[i + 2].opcode == OpCodes.Ble_S
                    || codes[i + 2].opcode == OpCodes.Ble_Un || codes[i + 2].opcode == OpCodes.Ble_Un_S))
            {
                codes[i + 2].opcode = codes[i + 2].opcode == OpCodes.Ble_S || codes[i + 2].opcode == OpCodes.Ble_Un_S
                    ? OpCodes.Br_S
                    : OpCodes.Br;
                FileLog.Log($"VakuuPlayer: takeover condition patched");
                break;
            }
        }
        return codes;
    }
}
