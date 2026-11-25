# 找奶龍：30 萬條洋流飄帶

Unity 6（6000.6.7f1）URP 第一人稱小品：用吸塵器把 30 萬條飄帶吸掉，找到埋在裡面的奶龍。

- 遊戲頁：https://swear01.itch.io/find-nailong（網頁版 WebGPU、Mac、Windows）
- 主要程式：`Assets/PileGame.cs`（飄帶堆、吸塵、HUD、自我檢查），飄帶用 `RibbonInstanced.shader` 從 GPU buffer 畫
- 場景和材質由 `Assets/Editor/Builder.cs` 產生，不用手動開編輯器

## 打包

```bash
U=/Applications/Unity/Hub/Editor/6000.6.7f1/Unity.app/Contents/MacOS/Unity
$U -batchmode -quit -projectPath "$PWD" -executeMethod Builder.Build         # Build/OceanBaby.app（本機測試）
$U -batchmode -quit -projectPath "$PWD" -executeMethod Builder.BuildRelease  # Release/mac、mac-intel、win（會先清空 Release/）
$U -batchmode -quit -projectPath "$PWD" -executeMethod Builder.BuildWeb      # Release/web（WebGPU）
```

自我檢查：`Build/OceanBaby.app/Contents/MacOS/OceanBaby -shot <前綴>`；網頁版在網址加 `?selfcheck`。

## 發佈

```bash
butler push Release/<mac|mac-intel|win|web> swear01/find-nailong:<mac|mac-intel|windows|html5> \
  --ignore=OceanBaby_BackUpThisFolder_ButDontShipItWithYourGame --userversion <版本>
```

飄帶貼圖：`uv run --with pillow Tools/make_textures.py`（用 macOS 的黑體，只在本機產圖，不打包字型）。HUD 字型 `Assets/Resources/Fonts/hud.otf` 是 Noto Sans CJK TC 的子集（OFL）。
