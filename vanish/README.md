# Vanish

讓玩家用同一個動作，感覺不同成長率有多大的差別。點中央數字累積餘額，右上角的「躍遷」會在本系走到目標時開放。

在 Mac 雙擊 [Vanish.command](Vanish.command)。用 Godot 4.7.2 開啟 [game/project.godot](game/project.godot) 可按 F5 執行。

- 點中央數字或按空白鍵，往當前數列走一項。這一步增加的量會加進餘額。
- 點「躍遷」或按 Enter 進入下一系。價格固定為這一系從起點走到目標所賺的一半，超額收入也會留下。例如第一系從 1 長到約 1.5702，扣約 0.2851，帶約 1.2851 進入調和系。再點一下加 1，餘額變成約 2.2851。
- 一般關在解鎖後額外點 2、6、14 下，可讓下一系的目標提前 1、2、3 下。斐波那契首次超過翻倍系的完整目標時，可以直接跳過翻倍系。
- 在最後的 Rayo 系完成符號預算，再按 Vanish 通關。關閉視窗會保存進度。

用 F1 可以查看目前規則與餘額算式，Esc 收起。後段以符號保留大數。數列的索引從新系的第一項開始，累積的餘額接著往上疊。

數學定義可參閱 [Friedman 的樹與圖](https://www.fomarchive.ugent.be/2006-April/010305.html)、[Busy Beaver Challenge](https://bbchallenge.org/link) 和 [Rayo 的定義遊戲](https://web.mit.edu/arayo/www/bignums.html)。
