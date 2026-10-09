# S1: London açılış kırılımı (Asya aralığı) ve S2: NY açılış kırılımı
import pandas as pd, numpy as np, itertools
from lib import *
df=load(); H=df.high.values; L=df.low.values; C=df.close.values; idx=df.index
def orb(range_h0,range_h1,trade_h0,trade_h1,exit_h,tp_r,sl_mode,buf_pts=5):
    rows=[]
    for d,g in df.groupby('date'):
        rng=g[(g.h>=range_h0)&(g.h<range_h1)]
        win=g[(g.h>=trade_h0)&(g.h<trade_h1)]
        if len(rng)<12 or len(win)==0: continue
        hi=rng.high.max(); lo=rng.low.min(); width=hi-lo
        atr=rng.atr.iloc[-1]
        if width<=0 or np.isnan(atr): continue
        ex=g[g.h<exit_h]
        if len(ex)==0: continue
        last_i=idx.get_loc(ex.index[-1])
        for t in win.index:
            i=idx.get_loc(t)
            up=H[i]>=hi+buf_pts*PT; dn=L[i]<=lo-buf_pts*PT
            if up and dn: break   # belirsiz bar, atla
            if up or dn:
                dr=1 if up else -1
                entry=hi+buf_pts*PT if up else lo-buf_pts*PT
                risk = width/2 if sl_mode=='mid' else sl_mode*atr*3
                sl=entry-dr*risk; tp=entry+dr*risk*tp_r
                xp,xi,why=walk(H,L,C,i,dr,entry,sl,tp,last_i)
                rows.append(dict(time=t,dir=dr,entry=entry,exit=xp,risk=risk,why=why))
                break
    return pd.DataFrame(rows)
res=[]
for name,(r0,r1,t0,t1,eh) in {'LON':(1,10,10,14,19),'NY':(10,16,16,19,22)}.items():
    for tp_r,slm in itertools.product([1.0,1.5,2.0,3.0],['mid',1.0,2.0]):
        tr=orb(r0,r1,t0,t1,eh,tp_r,slm)
        s=stats(tr,26,f'{name} tp{tp_r} sl{slm}')
        res.append(s)
for s in res: print(s['label'],'IS',s['IS'],'| OOS',s['OOS'])
