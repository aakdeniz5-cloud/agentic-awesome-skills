import pandas as pd, numpy as np, itertools
from lib import *
df=load(); O=df.open.values; H=df.high.values; L=df.low.values; C=df.close.values; idx=df.index
def lon(tp_r,sl_atr,buf_pts=5,t1=14,exit_h=19,max_w_atr=None,min_w_atr=None):
    rows=[]
    for d,g in df.groupby('date'):
        rng=g[(g.h>=1)&(g.h<10)]; win=g[(g.h>=10)&(g.h<t1)]
        if len(rng)<12 or len(win)==0: continue
        hi=rng.high.max(); lo=rng.low.min(); width=hi-lo; atr=rng.atr.iloc[-1]
        if width<=0 or np.isnan(atr): continue
        if max_w_atr and width>max_w_atr*atr: continue
        if min_w_atr and width<min_w_atr*atr: continue
        ex=g[g.h<exit_h]; last_i=idx.get_loc(ex.index[-1])
        for t in win.index:
            i=idx.get_loc(t)
            up=H[i]>=hi+buf_pts*PT; dn=L[i]<=lo-buf_pts*PT
            if up and dn: break
            if up or dn:
                dr=1 if up else -1
                lvl=hi+buf_pts*PT if up else lo-buf_pts*PT
                entry=max(O[i],lvl) if up else min(O[i],lvl)   # boşluklu açılışta açılış fiyatı
                risk=sl_atr*atr*3
                sl=entry-dr*risk; tp=entry+dr*risk*tp_r
                xp,xi,why=walk(H,L,C,i,dr,entry,sl,tp,last_i)
                rows.append(dict(time=t,dir=dr,entry=entry,exit=xp,risk=risk,why=why,width_atr=width/atr))
                break
    return pd.DataFrame(rows)
print('--- gap fix, cost 26 vs 40')
for tp_r in [1.5,2.0,3.0]:
    tr=lon(tp_r,1.0)
    for cost in (26,40):
        s=stats(tr,cost,f'tp{tp_r} cost{cost}'); print(s['label'],'IS',s['IS'],'| OOS',s['OOS'])
tr=lon(2.0,1.0)
tr['R']=((tr.exit-tr.entry)*tr.dir/PT-26)/(tr.risk/PT)
print('--- tp2 sl1: long/short')
for dr,g in tr.groupby('dir'): print('dir',dr,len(g),round(g.R.mean(),3),round(g.R.std()/np.sqrt(len(g)),3))
print('--- per quarter R sum / n')
q=tr.groupby(tr.time.dt.to_period('Q')).R.agg(['count','sum','mean']).round(2); print(q)
print('--- exits', tr.why.value_counts().to_dict())
print('--- avg risk $ per oz', round(tr.risk.mean(),2), 'median', round(tr.risk.median(),2))
# equity in R and max drawdown
eq=tr.R.cumsum(); dd=(eq.cummax()-eq).max(); print('total R',round(eq.iloc[-1],1),'maxDD R',round(dd,1),'longest losing streak', (tr.R<0).astype(int).groupby((tr.R>=0).cumsum()).sum().max())
# neighbours: sl 0.75/1.25, buffer 0/15, t1 13/15
print('--- neighbours (tp2)')
for kw in [dict(sl_atr=0.75),dict(sl_atr=1.25),dict(sl_atr=1.0,buf_pts=0),dict(sl_atr=1.0,buf_pts=15),dict(sl_atr=1.0,t1=12),dict(sl_atr=1.0,t1=16),dict(sl_atr=1.0,exit_h=17),dict(sl_atr=1.0,exit_h=21)]:
    s=stats(lon(2.0,**kw),26,str(kw)); print(s['label'],'IS',s['IS']['expR'],s['IS']['n'],'| OOS',s['OOS']['expR'],s['OOS']['n'])
tr.to_csv('lon_tp2_sl1.csv',index=False)
