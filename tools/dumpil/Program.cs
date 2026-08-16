using Mono.Cecil;
using Mono.Cecil.Cil;

// usage: dumpil <dll> <typeFilter> [memberFilter]
if (args.Length < 2) { Console.WriteLine("usage: dumpil <dll> <typeFilter> [memberFilter]"); return 1; }
var asm = AssemblyDefinition.ReadAssembly(args[0]);
var memberFilter = args.Length > 2 ? args[2] : null;

foreach (var type in asm.MainModule.Types.SelectMany(Traverse))
{
    if (!type.FullName.Contains(args[1], StringComparison.OrdinalIgnoreCase)) continue;
    Console.WriteLine($"\n// ===== {type.FullName} =====");
    foreach (var m in type.Methods)
    {
        if (memberFilter != null && !m.Name.Contains(memberFilter, StringComparison.OrdinalIgnoreCase)) continue;
        if (!m.HasBody) continue;
        Console.WriteLine($"\n// --- {m.Name}{m.MetadataToken} ---");
        foreach (var ins in m.Body.Instructions)
        {
            var operand = ins.Operand?.ToString() ?? "";
            if (operand.Length > 80) operand = operand[..80];
            Console.WriteLine($"  {ins.Offset:x4}: {ins.OpCode,-12} {operand}");
        }
    }
}
return 0;

static IEnumerable<TypeDefinition> Traverse(TypeDefinition t)
{
    yield return t;
    foreach (var n in t.NestedTypes.SelectMany(Traverse)) yield return n;
}
