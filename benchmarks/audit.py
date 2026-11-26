"""Audit actual emitted procedures with separate instrumented release builds.

Counters are deliberately excluded from the timing binaries. Fail closed if
a relevant emitter signature or operation changes; update this audit then.
"""
import hashlib
import json
import platform
from pathlib import Path
import re
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "benchmarks/build"
AUDIT = BUILD / "audit"
SDK = ROOT / "stdlib/native/nim"
N = 2_000_000
PASSES = 12
CHURN = 1_000_000
KEYS = ("typed_alloc", "typed_release", "typed_view", "typed_reserve",
        "typed_read", "typed_write", "raw_alloc", "native_free",
        "native_reserve", "native_rebase", "native_int_read", "native_int_write",
        "row_construct", "row_read", "get_value", "get_other",
        "policy_acquire")
EXPECTED_LAYOUTS = {
    "default": (32, 8, {"flag": 0, "value": 8, "category": 16, "other": 24}),
    "compact": (24, 8, {"flag": 16, "value": 0, "category": 17, "other": 8}),
    "wide": (64, 64, {"flag": 16, "value": 0, "category": 17, "other": 8}),
}

def run(*args, **kw):
    return subprocess.run([str(x) for x in args], cwd=ROOT, check=True, **kw)

def require(condition, msg):
    if not condition:
        raise RuntimeError(msg)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def bump(key, indent="  "):
    return f"{indent}if auditActive: inc auditCounts[{KEYS.index(key)}]"

def decode_hex(s):
    return bytes.fromhex(s.replace("_", "")).decode()

def encoded(s):
    return "_".join(f"{b:02X}" for b in s.encode())

def instrument_generated(source, label):
    lines = source.splitlines()
    out = ["import benchmark_audit"]
    seen = set()
    for line in lines:
        # All emitted definitions of interest have single-line signatures.
        out.append(line)
        m = re.match(r"proc (\w+)\(.* =\s*$", line)
        if m:
            name = m[1]
            key = None
            method = re.match(r"eido_method_\d+_(?:generic|nominal)_((?:[0-9A-F]{2}_)*[0-9A-F]{2})_(\w+)$", name)
            if method:
                owner, op = decode_hex(method[1]), method[2]
                if owner == "eido.stdlib.storage.Storage<Int>":
                    key = {"allocate":"typed_alloc", "release":"typed_release",
                           "view":"typed_view", "reserveAt":"typed_reserve",
                           "read":"typed_read", "write":"typed_write"}.get(op)
                elif owner.endswith(".InlineOnly") and op == "acquire":
                    key = "policy_acquire"
            hx = encoded("layout_bench.Row")
            if name.startswith("eido_storage_") and hx in name:
                if name.endswith("_writeConstruct"):
                    key = "row_construct"
                elif name.endswith("_compilerRead"):
                    key = "row_read"
                if key in ("row_construct","row_read"):
                    variant = label.removeprefix("layout-")
                    stride, alignment, _ = EXPECTED_LAYOUTS[variant]
                    out += ["  if auditActive:",
                            f"    doAssert storage.strideBytes == {stride}",
                            f"    doAssert cast[uint](storage.data) mod {alignment}'u == 0",
                            f"    doAssert storage.capacity == {N}"]
            if name.startswith(f"eido_get_nominal_{hx}_"):
                key = {"value":"get_value", "other":"get_other"}.get(name.split("_")[-1])
            if key:
                out.append(bump(key))
                seen.add(key)
            fn = re.match(r"eido_fn_\d+_nominal_((?:[0-9A-F]{2}_)*[0-9A-F]{2})$", name)
            if fn:
                logical = decode_hex(fn[1])
                if logical in {"storage_bench."+n for n in ("typed","rawView","churn","reuse","placement")}:
                    out += ["  auditActive = true", "  defer: auditActive = false"]
        # Layout verification and argument parsing are excluded from counters.
        if label.startswith("layout-") and re.match(r"  var eido_local_\d+_rows:.*allocate\(int64\(2000000\)\)", line):
            out[-1:-1] = ["  auditActive = true", "  defer: auditActive = false"]
    out.append("  auditReport()")
    # Last line must be within the generated when-isMainModule harness.
    require(lines[-1].strip() == "eido_string_shutdown()", f"{label}: unexpected harness")
    return "\n".join(out) + "\n", seen

def instrument_sdk():
    text = (SDK / "eido_storage.nim").read_text()
    edits = {
        "  result.data = cast[ptr UncheckedArray[int8]](alloc0(byteCount))": bump("raw_alloc"),
        "    dealloc(base)": bump("native_free", "    "),
        "  let start = checkedStorageSubrange(region, address, count, stride)": bump("native_reserve"),
        "  let target = checkedStorageSubrange(storage, alignedAddress, count, stride)": bump("native_rebase"),
    }
    for needle, extra in edits.items():
        require(text.count(needle) == 1, f"SDK changed: {needle}")
        text = text.replace(needle, extra + "\n" + needle)
    for operation in ("Read", "Write"):
        pattern = r"(proc eidoStorage" + operation + r"\*\[T\]\([^\n]+ =\n)"
        text, n = re.subn(pattern, lambda m: m[1] + "  when T is int64:\n" + bump("native_int_"+operation.lower(), "    ")+"\n", text)
        require(n == 1, f"SDK changed: {operation}")
    return "import benchmark_audit\n" + text

def compile_audit(label):
    path = BUILD / (label.replace("-", "_") + "_generated.nim")
    source = path.read_text()
    audited, seen = instrument_generated(source, label)
    directory = AUDIT / label
    directory.mkdir(exist_ok=True)
    target = directory / "instrumented.nim"
    target.write_text(audited)
    run("nim", "c", "-d:release", "--hints:off", f"--path:{AUDIT}",
        f"--nimcache:{directory / 'nimcache'}", f"-o:{directory/'program'}", target)
    return directory / "program", seen

def check_counts(counts, expected, positive=()):
    for key, val in expected.items():
        require(counts[key] == val, f"{key}: expected {val}, got {counts[key]}")
    for key in positive:
        require(counts[key] > 0, f"{key}: never executed")

def audit_run(binary, mode, checksum):
    p = run(binary, mode, capture_output=True, text=True)
    lines = p.stdout.strip().splitlines()
    require(len(lines) == 2 and int(lines[0]) == checksum, f"{binary} {mode}: bad output {lines}")
    values = [int(x) for x in lines[1].split(",")]
    require(len(values) == len(KEYS), "counter output mismatch")
    return dict(zip(KEYS, values))

def symbols(binary):
    result = run("nm", "-n", binary, capture_output=True, text=True).stdout
    return {parts[2]: int(parts[0], 16) for line in result.splitlines()
            if len(parts := line.split()) == 3 and re.fullmatch(r"[0-9a-fA-F]+", parts[0])}

def disassemble(binary, symbol):
    return run("objdump", "-d", "--disassemble="+symbol, binary,
               capture_output=True, text=True).stdout

def storage_native_calls(policy):
    binary = BUILD / f"storage-{policy}"
    sym = symbols(binary)
    evidence = {}
    chunks = []
    for fn in ("scan","typed","rawView","churn","reuse","placement"):
        hx = encoded("storage_bench."+fn).replace("_","")
        name, = [n for n in sym if re.match(r"eido_fn\d+_nominal"+hx+r"__",n)]
        asm = disassemble(binary,name)
        chunks.append(asm)
        calls = re.findall(r"\bcall\s+[^\n]*<([^>]+)>",asm)
        operations = []
        if fn in ("scan","churn","reuse","placement"):
            # Inlining can erase the call boundaries; verify direct memory
            # instructions in the workload itself when those symbols disappear.
            if not any(n.startswith("eidoStorageRead__") for n in sym):
                require((fn != "scan" or re.search(r"\bimul\b", asm)) and "raiseExceptionEx" in asm,
                        f"{policy}/{fn}: missing inlined address/check evidence")
                require(re.search(r"\b(?:mov|add)\w*\s+[^\n]*\([^\n]*%r", asm),
                        f"{policy}/{fn}: missing native memory access")
            else:
                operations += ["eidoStorageRead__","eidoStorageWrite__"]
        if fn in ("churn","reuse","typed"):
            operations += ["_allocate__","_release__"]
        if fn == "rawView":
            operations += ["eidoStorageAllocateRaw__","_view__","eidoStorageRelease__"]
        if fn == "placement":
            operations += ["_reserveAt__","eidoStorageAllocateRaw__","eidoStorageRelease__","_release__"]
        for op in operations:
            require(any(op in c for c in calls),f"{policy}/{fn}: native call {op} not found; inspect changed code generation")
        evidence[fn] = [c for c in calls if any(t in c for t in
                        ("eidoStorage","_allocate__","_release__","_reserveAt__","_view__"))]
    (AUDIT/f"storage-{policy}-native.txt").write_text("\n".join(chunks))
    return evidence

def actual_layout_probe(variant):
    # Inspect the uninstrumented timing executable on this host, at the actual
    # scan loop's native call site. Register locations use x86-64 SysV ABI.
    require(platform.machine() == "x86_64" and platform.system() == "Linux",
            "native debugger probe currently requires Linux x86-64")
    binary = BUILD / f"layout-{variant}"
    sym = symbols(binary)
    slots = [n for n in sym if n.startswith("eidoStorageSlotIdentity__")]
    main_hex = encoded("layout_bench.main").replace("_", "")
    main, = [n for n in sym if re.match(r"eido_fn\d+_nominal"+main_hex+r"__", n)]
    asm = disassemble(binary, main)
    if not slots:
        return inlined_layout_probe(variant, binary, sym, main, asm)
    slot, = slots
    calls = re.findall(r"^\s*([0-9a-f]+):[^\n]*\bcall\s+[^\n]*<"+re.escape(slot)+r">", asm, re.M)
    require(len(calls) == 2, f"{variant}: expected separate constructor and scan slot calls")
    offset = int(calls[1], 16)-sym[main]
    stride, alignment, fields = EXPECTED_LAYOUTS[variant]
    commands = [
        "set debuginfod enabled off", "set pagination off",
        f"break {slot}", "run scan",
        'printf "WRITE %ld %ld %ld\\n", *(long*)($rdi+8), *(long*)($rdi+16), $rsi',
        "continue",
        'printf "WRITE %ld %ld %ld\\n", *(long*)($rdi+8), *(long*)($rdi+16), $rsi',
        "disable 1", f"tbreak *{main}+{offset}", "continue",
        "set $base = *(unsigned long*)$rdi",
        f'printf "SCAN %ld %ld %ld %ld\\n", *(long*)($rdi+8), *(long*)($rdi+16), $rsi, $base % {alignment}',
    ]
    for j in range(2):
        addresses = []
        for f in ("flag","value","category","other"):
            ctype = "unsigned char" if f in ("flag","category") else "long"
            addresses.append(f"*({ctype}*)($base+{j*stride+fields[f]})")
        commands.append('printf "ROW %ld %ld %ld %ld\\n", '+", ".join(addresses))
    args = ["gdb","-q","-batch"]
    for cmd in commands:
        args.extend(["-ex",cmd])
    proc = run(*args, "--args",binary,capture_output=True,text=True)
    evidence = [line for line in proc.stdout.splitlines()
                if line.startswith(("WRITE ","SCAN ","ROW "))]
    expected = [f"WRITE {N} {stride} 0",f"WRITE {N} {stride} 1",
                f"SCAN {N} {stride} 0 0","ROW 1 1 2 2","ROW 1 2 2 3"]
    require(evidence==expected, f"{variant}: native scan probe failed: {evidence}")
    (AUDIT / f"layout-{variant}-native.txt").write_text(proc.stdout+proc.stderr+"\n"+asm)
    return evidence

def inlined_layout_probe(variant, binary, sym, main, asm):
    # Fail closed if this compiler's actual scan loop changes shape.
    # Identify the bounds comparison, descriptor stride, slot calculation
    # and first payload access in the optimized machine code, not a source
    # line or a breakpoint on a helper that no longer exists.
    stride, alignment, fields = EXPECTED_LAYOUTS[variant]
    instructions = []
    for line in asm.splitlines():
        m = re.match(r"^\s*([0-9a-f]+):\s+(?:[0-9a-f]{2}\s+)+\s*(.*)$", line)
        if m:
            instructions.append((int(m[1],16),m[2]))
    candidates = []
    for i in range(2,len(instructions)-4):
        cap = re.fullmatch(r"cmp\s+(0x[0-9a-f]+)\(%rsp\),%(r\w+)",instructions[i-2][1])
        load = re.fullmatch(r"mov\s+(0x[0-9a-f]+)\(%rsp\),%(r\w+)",instructions[i][1])
        if not (cap and load): continue
        if not instructions[i-1][1].startswith("jge"): continue
        if not re.fullmatch(r"imul\s+%"+cap[2]+",%"+load[2],instructions[i+1][1]): continue
        base = re.fullmatch(r"add\s+(0x[0-9a-f]+)\(%rsp\),%"+load[2],instructions[i+2][1])
        if not base or not instructions[i+3][1].startswith("js"): continue
        field = re.fullmatch(r"add\s+(?:(0x[0-9a-f]+))?\(%"+load[2]+r"\),%r\w+",instructions[i+4][1])
        if not field or int(field[1] or "0",16)!=fields["value"]: continue
        candidates.append((instructions[i+4][0]-sym[main],cap[1],load[1],base[1],cap[2],load[2]))
    require(len(candidates)==1,f"{variant}: expected one inlined scan address path, got {candidates}")
    off, cap, step, base, index, address = candidates[0]
    constructors=[n for n in sym if "_writeConstruct__" in n]
    require(len(constructors)==1, f"{variant}: constructor entry missing")
    commands=["set debuginfod enabled off","set pagination off",
              f"break {constructors[0]}","run scan",
              'printf "WRITE %ld %ld %ld\\n", *(long*)($rdi+8), *(long*)($rdi+16), $rsi',
              "continue",
              'printf "WRITE %ld %ld %ld\\n", *(long*)($rdi+8), *(long*)($rdi+16), $rsi',
              "disable 1",f"tbreak *{main}+{off}","continue",
              f"set $base = *(unsigned long*)($rsp+{base})",
              f'printf "SCAN %ld %ld %ld %ld\\n", *(long*)($rsp+{cap}), *(long*)($rsp+{step}), ${index}, $base % {alignment}',
              f'printf "ADDRESS %ld\\n", ${address} - $base']
    for j in range(2):
        addresses=[]
        for f in ("flag","value","category","other"):
            ctype="unsigned char" if f in ("flag","category") else "long"
            addresses.append(f"*({ctype}*)($base+{j*stride+fields[f]})")
        commands.append('printf "ROW %ld %ld %ld %ld\\n", '+", ".join(addresses))
    args=["gdb","-q","-batch"]
    for cmd in commands: args.extend(["-ex",cmd])
    proc=run(*args,"--args",binary,capture_output=True,text=True)
    evidence=[l for l in proc.stdout.splitlines() if l.startswith(("WRITE ","SCAN ","ADDRESS ","ROW "))]
    expected=[f"WRITE {N} {stride} 0",f"WRITE {N} {stride} 1",f"SCAN {N} {stride} 0 0",
              "ADDRESS 0","ROW 1 1 2 2","ROW 1 2 2 3"]
    require(evidence==expected,f"{variant}: inlined native scan probe failed: {evidence}")
    (AUDIT/f"layout-{variant}-native.txt").write_text(proc.stdout+proc.stderr+"\n"+asm)
    return evidence

def layout_oracle(variant):
    binary = BUILD / f"layout-{variant}"
    p = run(binary, "verify-"+variant, capture_output=True, text=True)
    require(p.stdout.strip() == "1", f"raw layout verification failed: {variant}")
    stride, alignment, offsets = EXPECTED_LAYOUTS[variant]
    source = (BUILD / f"layout_{variant}_generated.nim").read_text()
    hx = encoded("layout_bench.Row")
    # No policy lifecycle handlers were bound. Reject any emitted ones.
    for forbidden in ("memoryExecutionBoundary","memoryValueEnter","memoryValueLeave",
                      "memoryValueUpdate","ManagedGcRuntime",
                      "RcPolicyRuntime","MemoryValueRegistry"):
        require(forbidden not in source, f"{variant}: unexpected lifecycle instrumentation {forbidden}")
    require("template eidoMemoryTemporaryScope(body: untyped): untyped = body" in source,
            "temporary scope must be a compile-time identity template")
    # A standalone constructor must trigger the user-defined aborting handler.
    rejected = subprocess.run([str(binary), "verify-reject"], capture_output=True)
    require(rejected.returncode == 91, f"{variant}: allocation guard failed ({rejected.returncode})")
    for field, offset in offsets.items():
        for kind in ("get", "set"):
            pattern = rf"proc eido_{kind}_nominal_{hx}_{field}\([^\n]+ =\n  [^\n]*\+ uint\({offset}\)"
            require(re.search(pattern, source), f"{variant}: wrong {kind} offset {field}")
    require(f"bytes {{.align: {alignment}.}}: array[{stride}, byte]" in source, "payload representation mismatch")
    return {"stride": stride, "alignment": alignment, "offsets": offsets, "raw_round_trip": True, "standalone_allocation_rejected": True, "lifecycle_hooks": 0,
            "native_scan_probe": actual_layout_probe(variant)}

def audit():
    AUDIT.mkdir(parents=True, exist_ok=True)
    (AUDIT / "benchmark_audit.nim").write_text(
        f"var auditActive* = false\nvar auditCounts*: array[{len(KEYS)}, int64]\n"
        "proc auditReport*() =\n  var output = \"\"\n"
        "  for i, val in auditCounts:\n    if i > 0: output.add \",\"\n    output.add $val\n  echo output\n")
    (AUDIT / "eido_storage.nim").write_text(instrument_sdk())
    for provider in SDK.glob("eido_native*.nim"):
        shutil.copyfile(provider, AUDIT / provider.name)
    results = {}
    hashes = {}
    for policy in ("none",):
        label = "storage-"+policy
        binary, seen = compile_audit(label)
        require({"typed_alloc","typed_release","typed_read","typed_write","typed_view","typed_reserve"} <= seen, "missing typed operations")
        hashes[label] = digest(BUILD / (label.replace("-","_")+"_generated.nim"))
        for mode in ("typed","raw","churn","reuse","placement"):
            scan = mode in ("typed","raw")
            count = CHURN if not scan else N
            expected = {"typed_read": N*PASSES if scan else count,
                        "typed_write": count,
                        "native_int_read": N*PASSES if scan else count,
                        "native_int_write": count,
                        "typed_alloc": CHURN if mode=="churn" else int(mode in ("typed","reuse")),
                        "typed_release": CHURN if mode in ("churn","placement") else int(mode in ("typed","reuse")),
                        "typed_view": int(mode=="raw"),
                        "typed_reserve": CHURN if mode=="placement" else 0,
                        "raw_alloc": CHURN if mode=="churn" else 1,
                        "native_free": CHURN if mode=="churn" else 1,
                        "native_rebase": CHURN if mode=="churn" else int(mode in ("typed","reuse")),
                        "native_reserve": CHURN if mode=="placement" else 0,
                        "policy_acquire": 0}
            checksum = PASSES*N*(N+1)//2 if scan else CHURN*(CHURN+1)//2
            counts = audit_run(binary,mode,checksum)
            check_counts(counts,expected)
            results[f"{label}/{mode}"] = counts
    for variant in EXPECTED_LAYOUTS:
        label = "layout-"+variant
        oracle = layout_oracle(variant)
        binary, seen = compile_audit(label)
        require({"row_construct","row_read","get_value","get_other"} <= seen, "missing inline layout operations")
        counts = audit_run(binary,"scan",PASSES*N*(N+2))
        check_counts(counts,{"row_construct":N,"row_read":N*PASSES,"get_value":N*PASSES,
                             "get_other":N*PASSES,"policy_acquire":0,
                             "raw_alloc":1,"native_free":1,"native_int_read":0,"native_int_write":0})
        results[label] = {"oracle":oracle,"counts":counts}
        hashes[label] = digest(BUILD / (label.replace("-","_")+"_generated.nim"))
    binary_hashes = {name:digest(BUILD/name) for name in hashes}
    native_calls = {"none":storage_native_calls("none")}
    binary = BUILD / "native-storage"
    binary_hashes["native-storage"] = digest(binary)
    sym = symbols(binary)
    chunks = []
    for name in ("arrayScan","sdkScan","rawChurn","sdkChurn","sdkReuse","sdkPlacement"):
        symbol, = [n for n in sym if n.startswith(name+"__")]
        chunks.append(disassemble(binary,symbol))
    (AUDIT / "native-reference-assembly.txt").write_text("\n".join(chunks))
    binary = BUILD / "native-layout"
    binary_hashes["native-layout"] = digest(binary)
    sym = symbols(binary)
    chunks = [disassemble(binary,n) for n in sym if n.startswith("scan__layout_")]
    require(len(chunks)==3, "native layout scan routines missing")
    (AUDIT / "native-layout-assembly.txt").write_text("\n".join(chunks))
    output = {"generated_nim_sha256":hashes,"binary_sha256":binary_hashes,
              "native_sdk_sha256":digest(SDK/"eido_storage.nim"),"storage_native_calls":native_calls,"results":results}
    (BUILD / "audit-all.json").write_text(json.dumps(output,indent=2)+"\n")
    print(f"Verified {len(results)} Eido cases; evidence: {BUILD / 'audit-all.json'}",flush=True)
    return output

if __name__ == "__main__":
    audit()
