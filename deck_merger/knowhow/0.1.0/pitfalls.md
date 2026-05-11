# 陷阱與易錯點（0.1.0）

- 需要與列舉完全一致時，先輸出 `{"op":"all_actions"}`，再從回傳的 `legal_actions` 擇一；勿發明不存在的 `op` 或牌 id。
- `relic_offer_queue` 非空時只能選 `pick_relic`。
- 打出圖鑑前確認能量；圖鑑打出後 Exhaust。
