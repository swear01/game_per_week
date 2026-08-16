using System.Security.Cryptography;
using System.Text;

// pcktool list <file.pck> [filter] [--dir=<hex|auto>]
// pcktool extract <file.pck> <outdir> [filter] [--dir=<hex|auto>]
var dirArg = args.FirstOrDefault(a => a.StartsWith("--dir="))?.Substring(6);
var positional = args.Where(a => !a.StartsWith("--")).ToArray();
if (positional.Length < 2) { Console.WriteLine("usage: pcktool <list|extract> <file.pck> [filter] [--dir=<hex|auto>]"); return 1; }
var cmd = positional[0];
var path = positional[1];
var filter = positional.Length > 2 ? positional[2] : null;

long dir = -1;
if (dirArg != null)
{
    if (dirArg == "auto") dir = -1;
    else dir = Convert.ToInt64(dirArg, 16);
}

var files = ReadPck(path, out var baseOffset, dir);
if (cmd == "list")
{
    foreach (var f in files.Where(f => filter == null || f.Path.Contains(filter, StringComparison.OrdinalIgnoreCase)))
        Console.WriteLine($"{f.Offset,12} {f.Size,10}  {f.Path}");
    Console.WriteLine($"total: {files.Count} files");
}
else if (cmd == "extract")
{
    var outDir = positional[2];
    filter = positional.Length > 3 ? positional[3] : null;
    var matched = files.Where(f => filter == null || f.Path.Contains(filter, StringComparison.OrdinalIgnoreCase)).ToList();
    using var fs = File.OpenRead(path);
    foreach (var f in matched)
    {
        var dest = Path.Combine(outDir, f.Path.TrimStart('/').Replace('/', Path.DirectorySeparatorChar));
        try { Directory.CreateDirectory(Path.GetDirectoryName(dest)!); }
        catch (Exception e) { Console.Error.WriteLine($"skip bad path: {f.Path!r} -> {e.Message}"); continue; }
        fs.Seek(baseOffset + f.Offset, SeekOrigin.Begin);
        var buf = new byte[f.Size];
        fs.ReadExactly(buf);
        File.WriteAllBytes(dest, buf);
        Console.WriteLine($"  {dest} ({f.Size} bytes)");
    }
    Console.WriteLine($"extracted {matched.Count} files");
}
else { Console.WriteLine($"unknown command {cmd}"); return 1; }
return 0;

static List<PckEntry> ReadPck(string path, out long baseOffset, long forcedDir)
{
    using var fs = File.OpenRead(path);
    using var br = new BinaryReader(fs);
    var magic = new string(br.ReadChars(4));
    if (magic != "GDPC") throw new InvalidDataException($"not a godot pck: {magic}");
    var format = br.ReadUInt32();
    var major = br.ReadUInt32(); var minor = br.ReadUInt32(); var patch = br.ReadUInt32();
    var flags = br.ReadUInt32();
    if ((flags & 1) != 0) throw new InvalidDataException("encrypted pck not supported");
    baseOffset = br.ReadInt64();
    var headerDir = br.ReadInt64(); // v3: directory offset from header
    Console.Error.WriteLine($"GDPC v{format}, godot {major}.{minor}.{patch}, flags={flags}, base={baseOffset}, header_dir={headerDir:x}");

    var dir = forcedDir >= 0 ? forcedDir : headerDir;
    var list = new List<PckEntry>();
    // 若 header 目錄位置無效（遊戲重打包過），自動掃尾部找目錄
    br.BaseStream.Seek(dir, SeekOrigin.Begin);
    var probe = br.ReadInt32();
    if (probe <= 0 || probe > 1_000_000)
    {
        Console.Error.WriteLine($"header dir invalid (count={probe}), scanning tail for directory...");
        dir = FindDirectory(path);
        br.BaseStream.Seek(dir, SeekOrigin.Begin);
        probe = br.ReadInt32();
    }
    Console.Error.WriteLine($"using directory at {dir:x}, count={probe}");
    br.BaseStream.Seek(dir, SeekOrigin.Begin);
    var count = br.ReadInt32();
    list.Capacity = count;
    for (int i = 0; i < count; i++)
    {
        var pathLen = br.ReadInt32();
        var pathBytes = br.ReadBytes(pathLen);
        // 欄位含 pad 到 4 對齊，trim 尾零
        var entry = new PckEntry
        {
            Path = Encoding.UTF8.GetString(pathBytes).TrimEnd('\0'),
            Offset = br.ReadInt64(), // stored relative to file_base
            Size = br.ReadInt64(),
        };
        br.ReadBytes(16); // content md5
        entry.Flags = br.ReadUInt32();
        list.Add(entry);
    }
    return list;
}

static long FindDirectory(string path)
{
    // 目錄特徵：count(u32, 數千~數十萬) + path_len(u32, 10-400) + "res://"
    var size = new FileInfo(path).Length;
    using var fs = File.OpenRead(path);
    var chunk = 64 * 1024 * 1024; // 掃最後 128MB（分兩段）
    long scanStart = Math.Max(0, size - chunk * 2);
    fs.Seek(scanStart, SeekOrigin.Begin);
    var data = new byte[size - scanStart];
    fs.ReadExactly(data);
    for (long i = 0; i < data.Length - 16; i++)
    {
        if (data[i] != (byte)'r' || data[i + 1] != (byte)'e' || data[i + 2] != (byte)'s' || data[i + 3] != (byte)':') continue;
        var pathLen = BitConverter.ToInt32(data, (int)i - 4);
        var count = BitConverter.ToInt32(data, (int)i - 8);
        if (pathLen is >= 10 and <= 400 && count is >= 1000 and <= 1_000_000)
            return scanStart + i - 8;
    }
    throw new InvalidDataException("could not locate pck directory automatically; pass --dir=<hex>");
}

sealed class PckEntry { public string Path = ""; public long Offset; public long Size; public uint Flags; }
