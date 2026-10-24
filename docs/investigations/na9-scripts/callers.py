import sys, struct, json, mmap, bisect
from array import array
path, sel = sys.argv[1], sys.argv[2].encode()
allimps = sys.argv[3]
f = open(path,'rb'); mm = mmap.mmap(f.fileno(),0,access=mmap.ACCESS_READ)
hdr = mm[:0x8000]
ncmds, = struct.unpack('<I', hdr[16:20])
segs=[]; sects={}
off=32
for _ in range(ncmds):
    cmd,size=struct.unpack('<II',hdr[off:off+8])
    if cmd==0x19:
        vmaddr,vmsize,fileoff,filesize=struct.unpack('<QQQQ',hdr[off+24:off+56])
        segs.append((vmaddr,vmsize,fileoff,filesize))
        nsects,=struct.unpack('<I',hdr[off+64:off+68]); so=off+72
        for _ in range(nsects):
            sn=hdr[so:so+16].rstrip(b'\0').decode(); sg=hdr[so+16:so+32].rstrip(b'\0').decode()
            addr,sz,offs=struct.unpack('<QQI',hdr[so+32:so+52])
            sects[(sg,sn)]=(addr,sz,offs); so+=80
    off+=size
def v2o(v):
    for a,s,o,fs in segs:
        if a<=v<a+s: return o+v-a
    raise KeyError(hex(v))
M=(1<<36)-1
# 1 selector string
ma,ms,mo=sects[('__TEXT','__objc_methname')]
blob=mm[mo:mo+ms]
needle=b'\0'+sel+b'\0'
i=blob.find(needle)
if i<0: sys.exit('selector string not found')
straddr=ma+i+1
print('selector string at',hex(straddr))
# 2 selref slot
for key in (('__DATA','__objc_selrefs'),('__DATA_CONST','__objc_selrefs'),('__DATA_DIRTY','__objc_selrefs')):
    if key in sects: sa,ss,so_=sects[key]; break
arr=array('Q'); arr.frombytes(mm[so_:so_+ss])
idx=[k for k,v in enumerate(arr) if (v&M)==straddr]
print('selref slots:',[hex(sa+int(k)*8) for k in idx])
slots=set(sa+int(k)*8 for k in idx)
# 3 stubs
stubs=[]
if ('__TEXT','__objc_stubs') in sects:
    a,s,o=sects[('__TEXT','__objc_stubs')]
    code=array('I'); code.frombytes(mm[o:o+s])
    n=s//32
    for k in range(n):
        w=code[k*8:(k+1)*8]
        # adrp x1 ; ldr x1,[x1,#imm]
        ins0=int(w[0]); ins1=int(w[1])
        if (ins0 & 0x9f000000)==0x90000000:
            immlo=(ins0>>29)&3; immhi=(ins0>>5)&0x7ffff
            imm=(immhi<<2)|immlo
            if imm&0x100000: imm-=0x200000
            page=((a+k*32)&~0xfff)+(imm<<12)
            if (ins1 & 0xffc00000)==0xf9400000:
                off12=((ins1>>10)&0xfff)*8
                if page+off12 in slots: stubs.append(a+k*32)
print('stubs:',[hex(x) for x in stubs]); print([ (k,hex(v[0]),v[1]) for k,v in sects.items() if 'stub' in k[1] or k[1]=='__text'])
# 4 scan text
ta,ts,to=sects[('__TEXT','__text')]
text=array('I'); text.frombytes(mm[to:to+ts])
res=[]
if stubs:
    sset=set(stubs)
    for i,w in enumerate(text):
        if (w>>26)==0x25:
            imm=w&0x3ffffff
            if imm&0x2000000: imm-=0x4000000
            if ta+i*4+imm*4 in sset: res.append(ta+i*4)
# direct selref loads: adrp rd, page ; ldr x?, [rd, #off]  where page+off == slot
if not stubs:
    pages={}
    for sl in slots: pages.setdefault(sl&~0xfff,[]).append(sl)
    text=array('I'); text.frombytes(mm[to:to+ts])
    res=[]
    last={}  # reg -> (index, page)
    for i,w in enumerate(text):
        if (w & 0x9f000000)==0x90000000:
            immlo=(w>>29)&3; immhi=(w>>5)&0x7ffff
            imm=(immhi<<2)|immlo
            if imm&0x100000: imm-=0x200000
            last[w&0x1f]=(i,((ta+i*4)&~0xfff)+(imm<<12))
        elif (w&0xffc00000)==0xf9400000:
            rn=(w>>5)&0x1f
            ent=last.get(rn)
            if ent and i-ent[0]<=24 and ent[1] in pages:
                off12=((w>>10)&0xfff)*8
                if ent[1]+off12 in pages[ent[1]]: res.append(ta+i*4)
            # a load into rn overwrites it
            last.pop(w&0x1f,None)
    print('call sites via direct selref load:',len(res))
imps=json.load(open(allimps))
imps.sort(key=lambda x:x[0])
keys=[x[0] for x in imps]
for r in sorted(res):
    k=bisect.bisect_right(keys,r)-1
    owner=imps[k] if k>=0 else None
    print(hex(r), owner[2] if owner else '?', owner[1] if owner else '', hex(r-owner[0]) if owner else '')
