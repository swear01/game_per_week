using Steamworks;

// usage: subscribe <workshopItemId>
// 用當前登入的 Steam 用戶訂閱指定 workshop item（需要 Steam 客戶端運行中）
if (args.Length < 1) { Console.WriteLine("usage: subscribe <workshopItemId>"); return 1; }
ulong itemId = ulong.Parse(args[0]);

Console.WriteLine("Initializing Steamworks...");
if (!SteamAPI.IsSteamRunning())
{
    Console.WriteLine("Steam client is not running.");
    return 1;
}
var initResult = SteamAPI.InitEx(out var errMsg);
if (initResult != ESteamAPIInitResult.k_ESteamAPIInitResult_OK)
{
    Console.WriteLine($"SteamAPI.InitEx failed: {initResult} {errMsg}");
    return 1;
}
Console.WriteLine("Steamworks initialized.");

var id = new PublishedFileId_t(itemId);
Console.WriteLine($"Subscribing to {itemId}...");
SteamUGC.SubscribeItem(id);

// 等待 Steam 處理訂閱 + 開始下載
for (int i = 0; i < 30; i++)
{
    Thread.Sleep(2000);
    SteamAPI.RunCallbacks();
    var state = (EItemState)SteamUGC.GetItemState(id);
    Console.WriteLine($"  state: {state}");
    if ((state & EItemState.k_EItemStateInstalled) != 0)
    {
        Console.WriteLine("Item installed!");
        SteamAPI.Shutdown();
        return 0;
    }
}

Console.WriteLine("Item not installed within 60s (maybe still downloading).");
SteamAPI.Shutdown();
return 2;
