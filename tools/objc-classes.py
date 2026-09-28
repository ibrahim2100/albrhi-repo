#!/usr/bin/env python3
"""Print the real method list of a class, read from a Mach-O binary's ObjC metadata.

    python3 tools/objc-classes.py <binary> <ClassName> [ClassName...]

**Why this exists rather than a selector dump.** `otool -s __TEXT __objc_methname` lists every
selector name in an image and says nothing about which class answers which -- and this project
has lost releases to exactly that gap three times: `downloadAddr` (a real name, on no class we
touch), `bestURLtoDownload` (in a reference tweak's older build, absent here), and `bitRate`
(real, but on `TTKECVideoBitModel`, while the feed's `AWEVideoBSModel` says `bitrate`). A name
existing is not a name being answered. This walks `__objc_classlist` instead, so what it prints
is class membership.

**The one non-obvious mechanic: chained fixups.** In a modern arm64 image the quadwords in
`__DATA`/`__DATA_CONST` are not pointers. The low 36 bits are the target address and the high
bits are the fixup's own metadata, so every pointer read out of those sections has to be masked
before it means anything -- unmasked, the class list parses as one entry and the answer looks
like "not in this binary", which is a *wrong* answer rather than a failure.

Reading class metadata is also why no `class-dump` is needed: it parses what the runtime would.

Two more things it prints, both of which a method list cannot answer: the **class methods**
(read from the metaclass -- `+removeMessageWithMessageId:` is invisible in an instance list, and
one reference tweak hooked six of those), and the **ivars** with their types. A Swift-or-ObjC
variant object keeps each case's payload in a prefixed field (`_removeMessages_messageKeys`,
`_removeItem_messageId`), and the field is the only place that shape is written down.

    python3 tools/objc-classes.py <binary> --find-ivar <name>

lists every class declaring an ivar of that name -- the reverse question, for when the field is
known from a string dump and the class that owns it is not. `--find-method <selector>` does the
same for a method, instance or class, which is how a protocol's real implementers are found: a
selector in `__objc_methname` says somebody sends it, and only this says who answers it.
"""
import struct, sys

if len(sys.argv) < 3:
    sys.exit(__doc__)

path = sys.argv[1]
find_ivar = None
find_method = None
if sys.argv[2] in ('--find-ivar', '--find-method'):
    if len(sys.argv) < 4: sys.exit(__doc__)
    if sys.argv[2] == '--find-ivar': find_ivar = sys.argv[3]
    else: find_method = sys.argv[3]
    want = set()
else:
    want = set(sys.argv[2:])

f = open(path, 'rb')
hdr = f.read(0x8000)
ncmds, = struct.unpack('<I', hdr[16:20])

segs = []          # (vmaddr, vmsize, fileoff)
sections = {}      # (seg,sect) -> (addr, size)
off = 32
for _ in range(ncmds):
    cmd, size = struct.unpack('<II', hdr[off:off+8])
    if cmd == 0x19:
        segname = hdr[off+8:off+24].rstrip(b'\0').decode()
        vmaddr, vmsize, fileoff, filesize = struct.unpack('<QQQQ', hdr[off+24:off+56])
        segs.append((vmaddr, vmsize, fileoff))
        nsects, = struct.unpack('<I', hdr[off+64:off+68])
        so = off+72
        for _ in range(nsects):
            sect = hdr[so:so+16].rstrip(b'\0').decode()
            seg = hdr[so+16:so+32].rstrip(b'\0').decode()
            addr, sz = struct.unpack('<QQ', hdr[so+32:so+48])
            sections[(seg, sect)] = (addr, sz)
            so += 80
    off += size

MASK = (1<<36) - 1
def unchain(v):
    # Chained fixups: the stored quadword is not a pointer. Its low bits are the target's
    # unslid runtime address and the high bits are the fixup's own metadata, so every
    # pointer read out of __DATA/__DATA_CONST has to be masked before it means anything.
    return v & MASK

def foff(vm):
    vm = unchain(vm)
    for vmaddr, vmsize, fo in segs:
        if vmaddr <= vm < vmaddr + vmsize:
            return fo + (vm - vmaddr)
    return None

def read(vm, n):
    o = foff(vm)
    if o is None: return None
    f.seek(o); return f.read(n)

def cstr(vm):
    o = foff(vm)
    if o is None: return None
    f.seek(o); b = f.read(256)
    return b.split(b'\0')[0].decode('ascii', 'ignore')

def u64(vm):
    b = read(vm, 8)
    return struct.unpack('<Q', b)[0] if b else 0

def properties(list_vm):
    """objc_property_list: uint32 entsize, uint32 count, then {name, attributes} pointer pairs.

    Worth having next to the method list: the attribute string carries the declared *type*
    (`T@"AWEURLModel"`), which is the one thing a method name alone never tells you -- and
    following an accessor onto the wrong class is this project's most repeated bug."""
    if not list_vm: return []
    h = read(list_vm, 8)
    if not h: return []
    entsize, count = struct.unpack('<II', h)
    if count > 20000: return []
    body = read(list_vm + 8, entsize * count) or b''
    out = []
    for i in range(count):
        e = body[i*entsize:(i+1)*entsize]
        if len(e) < 16: break
        n, a = struct.unpack('<QQ', e[:16])
        name, attrs = cstr(unchain(n)), cstr(unchain(a))
        if not name: continue
        typ = attrs.split(',')[0][1:] if attrs and attrs.startswith('T') else '?'
        out.append('%s : %s' % (name, typ))
    return out

def methods(list_vm):
    """objc_method_list: uint32 entsize, uint32 count, then entries.
    entsize & 0x80000000 means relative (int32 offsets) -- what a modern arm64 binary uses."""
    if not list_vm: return []
    h = read(list_vm, 8)
    if not h: return []
    entsize, count = struct.unpack('<II', h)
    rel = bool(entsize & 0x80000000)
    entsize &= 0xffff
    out = []
    if count > 20000: return []
    body = read(list_vm + 8, entsize * count) or b''
    for i in range(count):
        e = body[i*entsize:(i+1)*entsize]
        if len(e) < 4: break
        if rel:
            d, = struct.unpack('<i', e[:4])
            # name field points at a selector-reference slot, which holds the real pointer
            ptr = u64(list_vm + 8 + i*entsize + d)
            # **The types field, printed because a selector's existence says nothing about its
            # signature.** This project crashed TikTok by declaring a hook's arguments from their
            # names: the real encoding had a `^q` out-parameter where an `NSInteger` was written and
            # a `void` return where `id` was. The second field of a method_t is a relative pointer
            # to that encoding, and it costs nothing to read while we are already here.
            t, = struct.unpack('<i', e[4:8]) if len(e) >= 8 else (0,)
            types = cstr(list_vm + 8 + i*entsize + 4 + t) if t else ''
            out.append((cstr(ptr), types))
        else:
            p, = struct.unpack('<Q', e[:8])
            t = unchain(struct.unpack('<Q', e[8:16])[0]) if len(e) >= 16 else 0
            out.append((cstr(p), cstr(t) if t else ''))
    return [m for m in out if m[0]]

def ivars(list_vm):
    """ivar_list_t: uint32 entsize, uint32 count, then {offset*, name, type, align, size}."""
    if not list_vm: return []
    h = read(list_vm, 8)
    if not h: return []
    entsize, count = struct.unpack('<II', h)
    if count > 20000 or entsize < 24: return []
    body = read(list_vm + 8, entsize * count) or b''
    out = []
    for i in range(count):
        e = body[i*entsize:(i+1)*entsize]
        if len(e) < 24: break
        _, n, t = struct.unpack('<QQQ', e[:24])
        name = cstr(unchain(n)) if n else None
        if not name: continue
        typ = cstr(unchain(t)) if t else ''
        out.append('%s : %s' % (name, typ or '?'))
    return out

def class_ro(cls_vm):
    c = read(cls_vm, 40)
    if not c: return None, None
    data_vm = unchain(struct.unpack('<Q', c[32:40])[0]) & ~7
    return c, read(data_vm, 72)

addr, size = sections[('__DATA', '__objc_classlist')] if ('__DATA','__objc_classlist') in sections \
    else sections[('__DATA_CONST', '__objc_classlist')]
blob = read(addr, size)
found = {}
for i in range(size // 8):
    cls_vm, = struct.unpack('<Q', blob[i*8:(i+1)*8])
    cls_vm = unchain(cls_vm)
    if not cls_vm: continue
    c = read(cls_vm, 40)
    if not c: continue
    data_vm, = struct.unpack('<Q', c[32:40])
    data_vm = unchain(data_vm) & ~7
    ro = read(data_vm, 72)
    if not ro: continue
    name_vm, = struct.unpack('<Q', ro[24:32])
    name_vm = unchain(name_vm)
    name = cstr(name_vm)
    # The superclass pointer is the second quadword of the class object, and it answers the one
    # question a method list cannot: whether several surfaces share a base worth hooking once.
    super_vm = unchain(struct.unpack('<Q', c[8:16])[0])
    super_name = None
    if super_vm:
        sc = read(super_vm, 40)
        if sc:
            sdata = unchain(struct.unpack('<Q', sc[32:40])[0]) & ~7
            sro = read(sdata, 72)
            if sro:
                super_name = cstr(unchain(struct.unpack('<Q', sro[24:32])[0]))

    ivars_vm = unchain(struct.unpack('<Q', ro[48:56])[0])
    if find_method:
        for sel, types in methods(unchain(struct.unpack('<Q', ro[32:40])[0])):
            if sel == find_method: print('-[%s %s]  %s' % (name, sel, types))
        meta_vm = unchain(struct.unpack('<Q', c[0:8])[0])
        if meta_vm:
            _, mro = class_ro(meta_vm)
            if mro:
                for sel, types in methods(unchain(struct.unpack('<Q', mro[32:40])[0])):
                    if sel == find_method: print('+[%s %s]  %s' % (name, sel, types))
        continue
    if find_ivar:
        for iv in ivars(ivars_vm):
            if iv.split(' : ')[0] == find_ivar:
                print('%s  (%s)' % (name, iv))
        continue

    if name in want:
        methods_vm = unchain(struct.unpack('<Q', ro[32:40])[0])
        props_vm = unchain(struct.unpack('<Q', ro[64:72])[0])
        # The metaclass is the class object's isa, and its method list is the class methods.
        class_methods = []
        meta_vm = unchain(struct.unpack('<Q', c[0:8])[0])
        if meta_vm:
            _, mro = class_ro(meta_vm)
            if mro:
                class_methods = sorted(set(methods(unchain(struct.unpack('<Q', mro[32:40])[0]))))
        found[name] = (sorted(set(methods(methods_vm))), sorted(set(properties(props_vm))),
                       super_name, class_methods, ivars(ivars_vm))

if find_ivar or find_method:
    sys.exit(0)

for n in sys.argv[2:]:
    print('===', n, '===')
    entry = found.get(n)
    if entry is None:
        print('  NOT IN THIS BINARY')
        continue
    ms, ps, super_name, cms, ivs = entry
    print('  superclass:', super_name or '?')
    if ps:
        print('  -- properties (name : declared type) --')
        print('  ' + '\n  '.join(ps))
    if ivs:
        print('  -- ivars (name : type encoding) --')
        print('  ' + '\n  '.join(ivs))
    if cms:
        print('  -- class methods --')
        cw = max(len(m[0]) for m in cms)
        for sel, types in cms:
            print('  +%-*s  %s' % (cw, sel, types or '?'))
    print('  -- methods (selector  type encoding) --')
    width = max([len(m[0]) for m in ms] or [0])
    for sel, types in ms:
        print('  %-*s  %s' % (width, sel, types or '?'))
