"""Generate explicit owning handles (Storage descriptors cannot be stored in Storage)."""
from pathlib import Path
p=Path(__file__).parent
lines=['// Derived from mimalloc-bench malloc-large; exact trace, alternating explicit owners.',
       'native function benchmarkNanos() returns Int;',
       'function allocateTrace(Storage<Int> slots, Storage<Int> sizes) returns Int {']
for i in range(20):
    lines += [f'    var a{i} = Storage<Byte>.allocate(0);',
              f'    var b{i} = Storage<Byte>.allocate(0);',
              f'    var bank{i} = false;']
lines += ['    var start = benchmarkNanos();','    var i = 0;',
          '    while (i < 2000) {','        var slot = Storage<Int>.read(slots, i);',
          '        var size = Storage<Int>.read(sizes, i);']
for i in range(20):
    lines += [f'        {"if" if i==0 else "else if"} (slot == {i}) {{',
              f'            if (bank{i}) {{',
              f'                Storage<Byte>.release(a{i});',
              f'                set a{i} = Storage<Byte>.allocate(size);',
              f'                Storage<Byte>.release(b{i});',
              f'                set b{i} = Storage<Byte>.allocate(0);',
              f'                set bank{i} = false;',
              '            } else {',
              f'                Storage<Byte>.release(b{i});',
              f'                set b{i} = Storage<Byte>.allocate(size);',
              f'                Storage<Byte>.release(a{i});',
              f'                set a{i} = Storage<Byte>.allocate(0);',
              f'                set bank{i} = true;',
              '            }','        }']
lines += ['        set i = i + 1;','    }','    var elapsed = benchmarkNanos() - start;']
for i in range(20):
    lines += [f'    Storage<Byte>.release(a{i});',
              f'    Storage<Byte>.release(b{i});']
lines += ['    return elapsed;','}']
(p/'Allocation.eido').write_text('\n'.join(lines)+'\n')
