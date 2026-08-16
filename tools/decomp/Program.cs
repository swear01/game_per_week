using ICSharpCode.Decompiler;
using ICSharpCode.Decompiler.CSharp;
using ICSharpCode.Decompiler.TypeSystem;

// usage: decomp <sts2.dll> <typeNameFilter> [memberFilter]
//   outputs full decompiled source of all types whose name contains filter
if (args.Length < 2) { Console.WriteLine("usage: decomp <dll> <typeFilter> [memberFilter]"); return 1; }
var dll = args[0];
var typeFilter = args[1];
var memberFilter = args.Length > 2 ? args[2] : null;

var decompiler = new CSharpDecompiler(dll, new DecompilerSettings(LanguageVersion.CSharp1));
var types = decompiler.TypeSystem.MainModule.TypeDefinitions
    .Where(t => t.FullName.Contains(typeFilter, StringComparison.OrdinalIgnoreCase))
    .ToList();
Console.Error.WriteLine($"matched {types.Count} types");
foreach (var t in types)
{
    Console.WriteLine($"\n// ===== {t.FullName} =====");
    try { Console.WriteLine(decompiler.DecompileTypeAsString(t.FullTypeName)); }
    catch (Exception e) { Console.Error.WriteLine($"FAILED {t.FullName}: {e.Message}"); }
}
return 0;
