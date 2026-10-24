import re,struct,sys,json
D='data/Library/MobileSubstrate/DynamicLibraries/NA9TikTok.dylib'
blob=open(D,'rb').read()
# segments
ncmds,=struct.unpack('<I',blob[16:20]); segs=[]; off=32
for _ in range(ncmds):
    cmd,size=struct.unpack('<II',blob[off:off+8])
    if cmd==0x19:
        vm,vs,fo,fs=struct.unpack('<QQQQ',blob[off+24:off+56]); segs.append((vm,vs,fo,fs))
    off+=size
def rd(v,n=1):
    for vm,vs,fo,fs in segs:
        if vm<=v<vm+vs:
            o=fo+v-vm
            return blob[o:o+n]
    return b'\0'*n
M=(1<<36)-1
def cstr(v):
    out=b''
    while True:
        c=rd(v,1)
        if c==b'\0' or len(out)>200: break
        out+=c; v+=1
    return out.decode('latin1')
mem={}  # written bytes
def rb(a):
    if a in mem: return mem[a]
    return rd(a,1)[0]
def wcstr(v):
    out=''
    for i in range(200):
        b=rb(v+i)
        if b==0: break
        out+=chr(b)
    return out
ALIAS={}
lines=[]
rx=re.compile(r'^\s*([0-9a-f]+):\s+(\w+)\s*(.*?)(?:\s*;.*)?$')
for l in open('dis.txt'):
    m=rx.match(l)
    if m: lines.append((int(m.group(1),16),m.group(2),m.group(3).strip()))
# aliases: stp; bl T; ldp; ret
idx={a:i for i,(a,_,_) in enumerate(lines)}
for i,(a,mn,op) in enumerate(lines):
    if mn=='stp' and i+3<len(lines) and lines[i+1][1]=='bl' and lines[i+2][1]=='ldp' and lines[i+3][1]=='ret':
        t=int(lines[i+1][2].split()[0],16); ALIAS[a]=t
def final(t):
    seen=0
    while t in ALIAS and seen<6: t=ALIAS[t]; seen+=1
    return t
NAMES={0x199cfc:'MSHookMessageEx',0x199d08:'NSClassFromString',0x19a05c:'class_addMethod',0x19a074:'class_getInstanceMethod',0x19a17c:'dlsym',0x19a3bc:'method_setImplementation',0x19a464:'objc_getClass',0x19a698:'sel_registerName',0x19a53c:'object_getClass',0x19a08c:'class_getSuperclass'}
reg={}
def val(r):
    return reg.get(r)
def parse_imm(s):
    s=s.strip().lstrip('#')
    return int(s,16) if s.startswith(('0x','-0x')) else int(s)
hooks=[]; strings={}
def setr(r,v):
    if v is None: reg.pop(r,None)
    else:
        reg[r]=v & (0xffffffffffffffff if r[0]=='x' else 0xffffffff)
def R(tok):
    tok=tok.strip()
    if tok=='sp' or tok in ('wzr','xzr'): return 0 if tok in ('wzr','xzr') else None
    return tok
def getv(tok):
    tok=tok.strip()
    if tok in ('wzr','xzr'): return 0
    # w/x alias same underlying
    n=tok[1:]
    return reg.get('x'+n) if tok[0] in 'xw' else None
def putv(tok,v):
    n=tok[1:]
    if v is None: reg.pop('x'+n,None)
    elif not isinstance(v,int): reg['x'+n]=v
    else: reg['x'+n]=v & (0xffffffffffffffff if tok[0]=='x' else 0xffffffff)
TRAMP=set(x+4 for x in ALIAS)
for (a,mn,op) in lines:
    try:
        if a in TRAMP: continue
        if a>=0x1997c8: break
        if mn=='adrp':
            rd_,imm=op.split(',')[0].strip(), int(op.split(',')[1].split()[0],16); putv(rd_,imm)
        elif mn=='add' and '#' in op and op.count(',')==2:
            d,n,i=[x.strip() for x in op.split(',')]
            nv=getv(n); putv(d, None if nv is None else nv+parse_imm(i))
        elif mn=='mov':
            d,s=[x.strip() for x in op.split(',',1)]
            if s.startswith('#'): putv(d,parse_imm(s))
            else: putv(d,getv(s))
        elif mn=='eor':
            p=[x.strip() for x in op.split(',')]
            a1=getv(p[1]); a2=parse_imm(p[2])&0xffffffff if p[2].startswith('#') else getv(p[2])
            putv(p[0], None if a1 is None or a2 is None else (a1^a2)&0xffffffff)
        elif mn in('ldrb','ldr') and '[' in op:
            d,m_=op.split(',',1)
            mm=re.match(r'\[(\w+)(?:,\s*#(-?0x[0-9a-f]+|-?\d+))?\]',m_.strip())
            if mm:
                base=getv(mm.group(1)); o=parse_imm(mm.group(2)) if mm.group(2) else 0
                if base is None: putv(d.strip(),None)
                elif mn=='ldrb': putv(d.strip(),rb(base+o))
                else:
                    if d.strip()[0]=='x': putv(d.strip(), struct.unpack('<Q',bytes(rb(base+o+k) for k in range(8)))[0] & M if True else 0)
                    else: putv(d.strip(),None)
            else: putv(d.split()[0].strip(),None)
        elif mn=='strb' and '[' in op:
            s,m_=op.split(',',1)
            mm=re.match(r'\[(\w+)(?:,\s*#(-?0x[0-9a-f]+|-?\d+))?\]',m_.strip())
            sv=getv(s.strip()); base=getv(mm.group(1)) if mm else None
            if mm and sv is not None and base is not None:
                mem[base+(parse_imm(mm.group(2)) if mm.group(2) else 0)]=sv&0xff
        elif mn=='bl':
            t=int(op.split()[0],16); f=final(t); nm=NAMES.get(f)
            if nm=='objc_getClass':
                x0=getv('x0'); s=wcstr(x0) if x0 else None
                if s is not None: strings[x0]=s
                putv('x0',('CLASS',s) if False else None); reg['x0']=('CLASS',s)
            elif nm=='object_getClass':
                c0=reg.get('x0'); reg['x0']=('+'+c0[1],) and ('CLASS','+'+c0[1]) if isinstance(c0,tuple) and c0[1] else None
            elif nm=='MSHookMessageEx':
                c=reg.get('x0'); cs=c[1] if isinstance(c,tuple) else (wcstr(c) if isinstance(c,int) and c else None)
                x1=getv('x1'); sel=cstr(x1 & M) if isinstance(x1,int) else None
                x2=getv('x2'); x3=getv('x3')
                hooks.append((a,cs,sel,x2,x3))
            else:
                for r in ('x0','x1','x2','x3','x4','x5','x6','x7','x8','x9','x10'): reg.pop(r,None)
        elif mn in('b','cbz','cbnz','tbz','tbnz','ret','blr','bl'):
            pass
        else:
            # other writes: invalidate first operand if it looks like a destination
            if mn not in('str','strh','stp','stlr','cmp','tst','nop','svc','brk','ldp') and op:
                d=op.split(',')[0].strip()
                if re.match(r'^[wx]\d+$',d): putv(d,None)
    except Exception as e:
        pass
print(len(hooks),'hook installs')
for a,c,s,f,o in hooks:
    print(hex(a),c,s,hex(f) if isinstance(f,int) else f)
