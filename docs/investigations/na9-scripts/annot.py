import sys,re,struct
src=open('emu.py').read().split("print(len(hooks),'hook installs')")[0]
exec(src)   # runs the emulator over everything: decoded strings in mem
lo,hi=int(sys.argv[1],16),int(sys.argv[2],16)
regs={}
def selname(ea):
    p=struct.unpack('<Q',rd(ea,8))[0]&M
    return cstr(p)
for (a,mn,op) in lines:
    if a<lo: continue
    if a>=hi: break
    if mn=='adrp': regs[op.split(',')[0].strip()]=int(op.split(',')[1].split()[0],16)
    elif mn=='add' and op.count(',')==2 and '#' in op:
        d,n,i=[x.strip() for x in op.split(',')]
        if n in regs: regs[d]=regs[n]+int(i.lstrip('#'),16 if i.startswith('#0x') else 10)
    elif mn=='ldr' and '[' in op:
        m=re.match(r'(x\d+),\s*\[(x\d+),\s*#(0x[0-9a-f]+)\]',op)
        if m and m.group(2) in regs:
            ea=regs[m.group(2)]+int(m.group(3),16)
            if 0x270d58<=ea<0x273c60: print(f"{a:x}: SEL  {selname(ea)}")
            elif 0x273c68<=ea<0x274108:
                p=struct.unpack('<Q',rd(ea,8))[0]&M; ro=struct.unpack('<Q',rd(p+32,8))[0]&M&~7
                print(f"{a:x}: CLASSREF {cstr(struct.unpack('<Q',rd(ro+24,8))[0]&M)}")
    if mn=='bl':
        t=int(op.split()[0],16); f=final(t)
        print(f"{a:x}: call {NAMES.get(f,hex(f))}")
    if mn=='mov' and re.match(r'w[2-4],\s*#',op): print(f"{a:x}: arg {op}")
    if mn=='add' and '#' in op and op.count(',')==2:
        d=op.split(',')[0].strip()
        if d in regs and 0x281000<=regs[d]<0x282000:
            s=wcstr(regs[d]); 
            if s and all(32<=ord(c)<127 or ord(c)>127 for c in s): print(f"{a:x}: STR {d}={s!r}")
