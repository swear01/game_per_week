# Vanish

讓玩家用同一個動作，感覺不同成長率有多大的差別。畫面只保留目前的量、下一下會改變什麼，以及何時可以換系。

在 Mac 雙擊 [Vanish.command](Vanish.command)。用 Godot 4.7.2 開啟 [game/project.godot](game/project.godot) 可按 F5 執行。

- 點中央數字或按空白鍵，往當前數列走一項。
- 達標時點右上角或按 Enter，從下一系的自然起點出發。上系紀錄會留在新塔底部。
- 想留下更大的紀錄，可以繼續點。一般關額外點 2、6、14 下，分別抵下一系 1、2、3 下。預覽以能達成的門檻為準。斐波那契首次超過翻倍系原價時，右上角會開啟專屬捷徑。
- 最後在 Rayo 系達到符號預算，按右上角的 Vanish 通關。遊戲會記住進度。

後段的大數保留定義式。顏色數、機器狀態數與符號預算都是可以直接數的參數。遊玩順序描述構造的變化，跨系的數值比較只在有依據時顯示。

數學定義可參閱 [Friedman 的樹與圖](https://www.fomarchive.ugent.be/2006-April/010305.html)、[Busy Beaver Challenge](https://bbchallenge.org/link) 和 [Rayo 的定義遊戲](https://web.mit.edu/arayo/www/bignums.html)。
