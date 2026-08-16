using System.Collections.Generic;
using System.Linq;
using HarmonyLib;
using MegaCrit.Sts2.Core.Localization;

namespace VakuuPlayer.Patches;

/// <summary>
/// 開局對話：涅奧（NEOW）保持顯示，但台詞換成瓦庫的契約之語。
/// 做法：不換 key（顯示的說話者名字由 key 前綴決定，必須保持 NEOW），
/// 而是訂閱語系切換事件，把 ancients 表裡 NEOW.talk.* 的值覆蓋為對應 VAKUU.talk.* 的文本。
/// 文本直接從表內複製，自動跟隨遊戲語言（eng / zht）。
/// </summary>
public static class NeowDialoguePatch
{
    private static bool _subscribed;

    public static void Initialize()
    {
        if (_subscribed)
        {
            return;
        }

        _subscribed = true;
        LocString.SubscribeToLocaleChange(ApplyOverrides);
        ApplyOverrides(); // 若表已載入則立即生效；未載入時由回呼接手
    }

    private static void ApplyOverrides()
    {
        try
        {
            var table = LocManager.Instance.GetTable("ancients");
            var overrides = new Dictionary<string, string>();
            foreach (var neowKey in table.Keys.Where(k => k.StartsWith("NEOW.talk.")))
            {
                var vakuuKey = "VAKUU" + neowKey.Substring("NEOW".Length);
                if (table.HasEntry(vakuuKey) && table.HasEntry(neowKey))
                {
                    overrides[neowKey] = table.GetRawText(vakuuKey);
                }
            }

            if (overrides.Count > 0)
            {
                table.MergeWith(overrides);
                FileLog.Log($"VakuuPlayer: Neow dialogue overridden with Vakuu's lines ({overrides.Count} entries)");
            }
        }
        catch (System.Exception e)
        {
            FileLog.Log($"VakuuPlayer: Neow override failed (table not ready?): {e.Message}");
        }
    }
}
