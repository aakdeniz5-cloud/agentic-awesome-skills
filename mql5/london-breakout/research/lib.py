import pandas as pd, numpy as np
PT=0.01
SPLIT=pd.Timestamp('2026-02-01')
def load():
    df=pd.read_csv('bars.csv',comment='#')
    df['time']=pd.to_datetime(df['time'],format='%Y.%m.%d %H:%M')
    df=df.set_index('time')
    df['date']=df.index.normalize()
    df['h']=df.index.hour; df['m']=df.index.minute
    tr=np.maximum(df.high-df.low,np.maximum(abs(df.high-df.close.shift()),abs(df.low-df.close.shift())))
    df['atr']=tr.rolling(14).mean()
    return df

def walk(H,L,C,i0,direction,entry,sl,tp,last_i):
    """walk bars from i0 (entry bar inclusive) to last_i; SL first if both hit in same bar.
    returns exit price, exit index, reason"""
    for i in range(i0,last_i+1):
        if direction>0:
            if L[i]<=sl: return sl,i,'sl'
            if tp is not None and H[i]>=tp: return tp,i,'tp'
        else:
            if H[i]>=sl: return sl,i,'sl'
            if tp is not None and L[i]<=tp: return tp,i,'tp'
    return C[last_i],last_i,'time'

def stats(tr,cost_pts,label=''):
    """tr: DataFrame with time, dir, entry, exit, risk(price). cost in points per trade (round trip)"""
    if len(tr)==0: return dict(label=label,n=0)
    pnl=(tr.exit-tr.entry)*tr.dir/PT - cost_pts   # points per 1 unit
    R=pnl/(tr.risk/PT)
    out={}
    for name,mask in (('IS',tr.time<SPLIT),('OOS',tr.time>=SPLIT)):
        r=R[mask]; p=pnl[mask]
        if len(r)==0: out[name]=None; continue
        gp=p[p>0].sum(); gl=-p[p<0].sum()
        out[name]=dict(n=int(len(r)),expR=round(r.mean(),3),se=round(r.std()/np.sqrt(len(r)),3),
                      PF=round(gp/gl,2) if gl>0 else None,win=round((p>0).mean()*100,1),sumR=round(r.sum(),1))
    out['label']=label
    return out
