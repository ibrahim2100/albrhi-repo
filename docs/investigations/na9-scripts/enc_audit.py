import re,sys,json,glob,os
dump=json.load(open(sys.argv[1]))["classes"]
cls={c["name"]:c for c in dump} if isinstance(dump,list) else dump
TMAP=[(r'^(void)$','v'),(r'^(BOOL|bool)$','B'),(r'^(id|instancetype|Class)\b.*$','@'),(r'.*\*$','@'),
 (r'^(NSInteger|long long|long|int64_t)$','q'),(r'^(NSUInteger|unsigned long long|unsigned long|uint64_t|size_t)$','Q'),
 (r'^(double|CGFloat|NSTimeInterval)$','d'),(r'^(int|int32_t)$','i'),(r'^(unsigned int|uint32_t|unsigned)$','I'),(r'^(float)$','f'),(r'^SEL$',':')]
def code(t):
    t=re.sub(r'\b(const|nonnull|nullable|__kindof|__unused|__weak|__strong)\b','',t).strip()
    t=re.sub(r'<[^>]*>','',t).strip()
    for pat,c in TMAP:
        if re.match(pat,t): return c
    if re.match(r'^[A-Z]\w+$',t): return '?'+t
    return '?'+t
def first(enc):
    # first type char of return
    i=0
    while i<len(enc) and enc[i] in 'rnNoORV': i+=1
    return enc[i]
def argchars(enc):
    # strip digits; split into types at offsets: crude — remove numbers, then tokens
    t=re.sub(r'\d+','',enc)
    out=[];i=0
    while i<len(t):
        c=t[i]
        if c in 'rnNoORV': i+=1; continue
        if c=='@':
            out.append('@'); i+=1
            if i<len(t) and t[i]=='"':
                j=t.index('"',i+1); i=j+1
            elif i<len(t) and t[i]=='?': i+=1
            continue
        if c in '{(':
            op,cl=('{','}') if c=='{' else ('(',')')
            d=0
            for j in range(i,len(t)):
                if t[j]==op: d+=1
                elif t[j]==cl:
                    d-=1
                    if d==0: break
            out.append('S'); i=j+1; continue
        if c=='^':
            i+=1
            continue
        out.append(c); i+=1
    return out
bad=0
for f in sorted(glob.glob('**/*.x',recursive=True)+glob.glob('**/*.xm',recursive=True)):
    src=open(f).read()
    src=re.sub(r'//[^\n]*','',src); src=re.sub(r'/\*.*?\*/','',src,flags=re.S)
    cur=None
    for m in re.finditer(r'%hook\s+(\w+)|%end|^([-+])\s*\(([^)]*)\)\s*([^{;]*)\{',src,flags=re.M):
        if m.group(1): cur=m.group(1); continue
        if m.group(0)=='%end': cur=None; continue
        if not cur: continue
        kind,ret,sig=m.group(2),m.group(3),m.group(4)
        parts=re.findall(r'(\w*):\s*\(([^)]*)\)\s*\w+',sig)
        if parts: sel=''.join(p[0]+':' for p in parts); args=[code(p[1]) for p in parts]
        else: sel=sig.strip(); args=[]
        c=cls.get(cur)
        if not c: continue
        tbl=(c["methods"] if kind=='-' else c["class_methods"])
        enc=tbl.get(sel)
        if not enc: continue
        got=[first(enc)]+argchars(enc)[3:]
        want=[code(ret)]+args
        def eq(a,b):
            if a.startswith('?') or b.startswith('?'): return True  # unknown typedef: not judged
            return a==b or (a=='@' and b=='@')
        if len(got)!=len(want) or not all(eq(a,b) for a,b in zip(want,got)):
            bad+=1; print(f"{f}: {cur} {kind}{sel}  hook={want}  real={got}  enc={enc}")
print("mismatches:",bad)
