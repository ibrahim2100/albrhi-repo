import re,struct,json
exec(open('emu.py').read().split("reg={}")[0])
hooks=json.load(open('na9-hooks.json'))
addrs=sorted(set(int(h[2],16) for h in hooks))
allfun=set()
# function starts: lines following 'ret' preceded... use stp x29,x30 pushes as starts
starts=[a for (a,mn,op) in lines if mn in('stp','sub') and ('x29, x30, [sp' in op or 'sp, sp' in op)]
starts=sorted(set(starts))
import bisect
def span(a):
    i=bisect.bisect_right(starts,a)
    # extend until next hook address or 0x2000 bytes
    nxt=[x for x in addrs if x>a]
    end=min(nxt[0] if nxt else a+0x3000, a+0x3000)
    return a,end
reg={}
def run(a,e):
    sels=[];cls=[];strs=[]
    reg={}
    for (ad,mn,op) in lines:
        if ad<a: continue
        if ad>=e: break
        if mn=='adrp':
            d=op.split(',')[0].strip(); reg[d]=int(op.split(',')[1].split()[0],16)
        elif mn=='add' and op.count(',')==2 and '#' in op:
            d,n,i=[x.strip() for x in op.split(',')]
            if n in reg: reg[d]=reg[n]+int(i.lstrip('#'),16 if i.startswith('#0x') else 10)
        elif mn=='ldr' and '[' in op:
            m=re.match(r'(x\d+),\s*\[(x\d+),\s*#(0x[0-9a-f]+)\]',op)
            if m and m.group(2) in reg:
                ea=reg[m.group(2)]+int(m.group(3),16)
                if 0x270d58<=ea<0x273c60:
                    p=struct.unpack('<Q',rd(ea,8))[0]&M; sels.append(cstr(p))
                elif 0x273c68<=ea<0x274108:
                    # classref -> class name via class object: read name
                    p=struct.unpack('<Q',rd(ea,8))[0]&M
                    ro=struct.unpack('<Q',rd(p+32,8))[0]&M&~7
                    nm=struct.unpack('<Q',rd(ro+24,8))[0]&M
                    cls.append(cstr(nm))
    return sels,cls
out={}
for h in hooks:
    a=int(h[2],16); a0,e=span(a)
    s,c=run(a0,e)
    out[f"{h[0]} {h[1]}"]=(sorted(set(s)),sorted(set(c)))
json.dump(out,open('na9-vocab.json','w'),indent=1)
for k,(s,c) in out.items():
    s=[x for x in s if x not in('class','alloc','init','isKindOfClass:','respondsToSelector:','isEqualToString:','length','count','objectAtIndex:','stringWithFormat:','boolForKey:','boolValue','release','retain','autorelease','description','copy')]
    print(k,'|',', '.join(s[:14]),'|',', '.join(c[:4]))
