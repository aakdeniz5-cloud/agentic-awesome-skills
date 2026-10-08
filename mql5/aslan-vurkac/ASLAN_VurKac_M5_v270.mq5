//+------------------------------------------------------------------+
//| ASLAN Video Grid Reconstruction v2.35                            |
//| Rolling two-sided grid based on the supplied video frames.       |
//| This is a reconstruction, NOT the original proprietary source.  |
//+------------------------------------------------------------------+
#property strict
#property version "2.70"
#property description "ASLAN Vur-Kac M5 v2.70 LIVE - grid + basket trailing, live-account protections (spread, rollover, news, commission, margin, execution log)"

#include <Trade/Trade.mqh>
CTrade trade;

//======================== GRID & LOTS ==============================
// RECOMMENDED: XAUUSD M5 - SCALP / VUR-KAC
// Existing pending orders are preserved. The EA replenishes only the
// side that gets triggered instead of deleting and rebuilding the grid.
input group "GRID & LOTS"
input int    LevelsPerSide          = 4;
input double GridDistancePoints     = 15.0;   // 15 points = about $0.15 on 2-digit XAUUSD
input bool   ScaleSpacingByPrice     = false;
input double PriceScalePercent       = 0.0125;
input bool   KeepStopsOnChart       = true;
input bool   StartWithBuySellStops  = true;
input int    MaximumPositions       = 12; // allows a one-way rally to keep replenishing while opposite pending orders remain
input double MaximumSpreadPoints    = 35.0;  // v2.70: 80 -> 35 (SL 30 point iken 80 point spread anlamsız)

input group "AUTOMATIC BALANCE LOT"
input bool   UseAutomaticBalanceLot = true;
input double BalanceStepMoney       = 1000.0; // every $1000 balance adds one 0.01 lot step
input double LotStepPerBalance      = 0.01;
input double MaximumAutoLot          = 0.03;
input double ManualLot               = 0.01;

//======================== POSITION SL ==============================
input group "POSITION SL"
input bool   UseInitialSL           = true;
input double InitialSLPoints        = 30.0;

//======================== PROFIT TARGETS ============================
input group "PROFIT TARGETS"
input bool   UseCycleNetBankTarget  = false;
input double CycleNetBankTarget     = 50.0;
input bool   UseWholeBookGreenBank  = false;
input double WholeBookGreenTarget   = 10.0;

//======================== DAILY LIMITS =============================
input group "DAILY LIMITS"
input bool   UseDailyNetTarget      = true;
input double DailyNetTarget         = 100.0;
input bool   UseDailyNetLossLimit   = true;
input double DailyNetLossLimit      = 30.0;
input bool   UseEquityDDLimit       = true;
input double MaximumDrawdownPercent = 10.0;

//======================== TRAILLOCK =================================
input group "BASKET PROFIT PROTECTION"
input bool   UseBasketMoneyTrail    = true;
input double BasketTrailStartMoney  = 5.0;
input double BasketTrailGivebackMoney= 3.0;  // +15 peak -> +12 protected
input double BasketTrailStepMoney   = 1.0;
input bool   CloseBasketOnTrailHit   = true; // close the active basket when peak giveback is reached

// Optional per-position protection remains available.
input bool   UsePerLegTrailing       = false;
input double TrailArmMoney           = 1.00;
input double TrailLockMoney          = 0.50;
input double TrailDistancePoints     = 20.0;
input double TrailStepPoints         = 5.0;
input bool   TrailProfitableLegsOnly = true;

//======================== RECOVERY BREAK-EVEN ======================
input bool   UseRecoveryBreakEven          = true;
input double RecoveryArmLossMoney          = 0.50;
input double RecoveryBreakEvenNetMoney     = 0.10;

//======================== PERSISTENT REPLENISHING GRID =============
input group "PERSISTENT GRID"
input bool   ReplenishTriggeredSide        = true;
input bool   ReplenishOppositeSide         = true;
input int    MaxPendingPerSide             = 4;
input double ReplenishMinMovePoints        = 5.0;
input bool   DeletePendingOnlyOnRiskStop   = true;
input bool   StopNewGridAfterLock           = false; // keep pending grid active after profit lock
input group "ACTIVE DIRECTION"
input bool   UseActiveDirectionMode          = true;
input double DirectionSwitchPoints           = 30.0; // reverse only after a meaningful move
input bool   CancelOppositePendingOnSwitch   = true;

//======================== TRADING ==================================
input group "TRADING"
input bool   AllowBuy               = true;
input bool   AllowSell              = true;
input long   MagicNumber            = 2026091501;
input int    SlippagePoints         = 30;

//======================== LIVE PROTECTION (v2.70) ==================
// EC Markets notlarına göre canlı hesap korumaları:
//  1) point ayarları 2/3 basamaklı fiyatta aynı dolar mesafesi
//  2) grid aralığı ve SL ortalama spread'in katından küçük olamaz
//  3) spread sıçraması, rollover / seans açılışı ve haberde bekleyen emir yok
//  4) net hesaplarda kapanış komisyonu da dahil
//  5) marj seviyesi ve toplam lot sınırı
//  6) her gerçekleşen emir için kayma (slippage) ve spread günlüğü
input group "LIVE PROTECTION"
input bool   AutoScalePoints          = true;   // 3/5 basamaklı fiyatta tüm *Points ayarları x10 (XAUUSD 2 basamak bazlı)
input double CommissionPerLotPerSide  = 3.0;    // Komisyon USD / lot / işlem (EC Markets XAUUSD.n: 3 USD, açılış + kapanış)
input double GridSpreadMultiplier     = 2.0;    // Grid aralığı >= (ortalama spread + komisyon maliyeti) x bu (0 = kapalı)
input double SLSpreadMultiplier       = 3.0;    // SL >= (ortalama spread + komisyon maliyeti) x bu (0 = kapalı)
input int    SpreadAverageTicks       = 300;    // Ortalama spread için tick sayısı (EMA)
input double SpreadSpikeMultiplier    = 2.0;    // Spread > ortalama x bu ise sıçrama say (0 = kapalı)
input bool   DeletePendingWhenBlocked = true;   // Engel durumunda (spread/rollover/haber/marj) bekleyen emirleri sil
input bool   UseRolloverFilter        = true;   // Sunucu gece yarısı (rollover) çevresinde emir yok
input int    RolloverMinutesBefore    = 15;     // Gece yarısından kaç dk önce
input int    RolloverMinutesAfter     = 30;     // Gece yarısından kaç dk sonra
input bool   CloseBeforeRollover      = true;   // Rollover penceresi başlayınca açık pozisyonları kapat (swap + ara riski)
input int    SessionOpenSkipMinutes   = 30;     // Piyasa açılışı / günlük ara sonrası ilk X dk emir yok (XAUUSD.n: işlem 01:05'te açılır)
input bool   UseNewsFilter            = true;   // Yüksek önemli haberlerde emir yok (sadece canlı/demo; tester'da çalışmaz)
input string NewsCurrencies           = "USD";  // Haber para birimleri (virgülle)
input int    NewsMinutesBefore        = 15;     // Haberden kaç dk önce
input int    NewsMinutesAfter         = 15;     // Haberden kaç dk sonra
input bool   CountClosingCommission   = true;   // Net hesaplara kapanış komisyonunu da ekle (açılışla aynı varsayılır)
input double MinMarginLevelPercent    = 1000.0; // Marj seviyesi bunun altındaysa yeni emir yok (0 = kapalı)
input double MaxTotalLots             = 0.30;   // Açık + bekleyen toplam lot sınırı (0 = kapalı)
input bool   LogExecutions            = true;   // Gerçekleşmeleri Common\Files\ASLAN_exec_<hesap>.csv dosyasına yaz

//======================== INFO / MEMO ==============================
// Chart recommendation: XAUUSD M5.
// Style: SCALP / VUR-KAC.
// Grid orders are persistent; only missing levels are replenished.
// A one-way rally does not exhaust the side: triggered SELLs are replaced
// below price and triggered BUYs are replaced above price automatically.
// Lot is calculated from the live account balance when automatic lot is on.

//======================== STATE ====================================
double gridCenterPrice = 0.0;
bool   cycleActive = false;
int    cycleId = 0;
int    lockedDay = -1;
bool   dailyLocked = false;
double lastEntryPrice = 0.0;
bool trailLockActive = false;

// TOTAL basket trailing state. It is deliberately independent of BUY/SELL
// direction so a hedged basket is protected by the combined net result.
double totalBasketPeak = 0.0;
bool   totalBasketTrailArmed = false;

// Active-direction grid state: only one pending side is maintained after
// a meaningful directional move. The opposite side is re-armed only after
// a real reversal, instead of waiting passively at stale prices.
int    activeGridDirection = 0; // 0=neutral, 1=BUY, -1=SELL
 double directionAnchorPrice = 0.0;

// v2.70 canlı hesap durumu
double   g_scale        = 1.0;   // point ölçek çarpanı
double   g_avgSpread    = 0.0;   // ortalama spread (fiyat birimi)
bool     g_blocked      = false; // yeni bekleyen emir engeli
string   g_blockReason  = "";
datetime g_lastTickTime = 0;
datetime g_sessionOpen  = 0;
datetime g_newsTimes[];
datetime g_lastNewsLoad = 0;
string   g_newsCur[];
ulong    g_commId[];
double   g_commVal[];
double   g_slipSum      = 0.0;
double   g_slipMax      = 0.0;
int      g_slipCount    = 0;

//--- İşlem başı maliyet (fiyat birimi): ortalama spread + açılış/kapanış komisyonu.
//    XAUUSD.n: 3 USD x 2 / 100 kontrat = 0.06 USD = 6 point
double TradingCostPrice()
{
   double contract=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
   double comm=(contract>0.0 ? 2.0*CommissionPerLotPerSide/contract : 0.0);
   return g_avgSpread+comm;
}

//--- Ayar point'ini fiyat birimine çeviren ölçekli point
double PT()
{
   return _Point*g_scale;
}

string RecoveryKey(ulong ticket)
{
   return StringFormat("ASLAN_RBE_%I64u",ticket);
}

int RecoveryState(ulong ticket)
{
   string key=RecoveryKey(ticket);
   if(!GlobalVariableCheck(key)) return 0;
   return (int)GlobalVariableGet(key);
}

void SetRecoveryState(ulong ticket,int state)
{
   GlobalVariableSet(RecoveryKey(ticket),(double)state);
}

void ManageRecoveryBreakEven()
{
   if(!UseRecoveryBreakEven) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return;

   double stopLevel=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double freeze=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*_Point;
   double minDist=MathMax(stopLevel,freeze)+2.0*_Point;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!IsOurPosition(ticket)) continue;

      int state=RecoveryState(ticket);
      double net=PositionNetProfit();
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double oldSL=PositionGetDouble(POSITION_SL);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double swap=PositionGetDouble(POSITION_SWAP);
      double commission=PositionCommissionForSelectedPosition();
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      // First arm only after a meaningful NET loss.
      if(state==0 && net<=-MathAbs(RecoveryArmLossMoney))
      {
         SetRecoveryState(ticket,1);
         state=1;
         Print("ASLAN RECOVERY BE ARMED | ticket=",ticket," | net=",DoubleToString(net,2));
      }

      // After recovery, move SL to a NET break-even / small-profit level.
      if(state!=1 || net<RecoveryBreakEvenNetMoney) continue;

      double currentPrice=(type==POSITION_TYPE_BUY ? t.bid : t.ask);
      double newSL=StopPriceForNetLock(type,volume,entry,currentPrice,swap,commission,RecoveryBreakEvenNetMoney);
      if(newSL<=0.0) continue;
      newSL=NormalizePrice(newSL);

      if(type==POSITION_TYPE_BUY)
      {
         if(newSL>t.bid-minDist) continue;
         if(oldSL>0.0 && newSL<=oldSL) { SetRecoveryState(ticket,2); continue; }
      }
      else if(type==POSITION_TYPE_SELL)
      {
         if(newSL<t.ask+minDist) continue;
         if(oldSL>0.0 && newSL>=oldSL) { SetRecoveryState(ticket,2); continue; }
      }
      else continue;

      trade.SetExpertMagicNumber(MagicNumber);
      ResetLastError();
      bool ok=trade.PositionModify(ticket,newSL,PositionGetDouble(POSITION_TP));
      uint rc=trade.ResultRetcode();

      if(ok && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL || rc==TRADE_RETCODE_PLACED))
      {
         SetRecoveryState(ticket,2);
         Print("ASLAN RECOVERY BE OK | ticket=",ticket,
               " | recoveredNet=",DoubleToString(net,2),
               " | lockNet=",DoubleToString(RecoveryBreakEvenNetMoney,2),
               " | entry=",DoubleToString(entry,_Digits),
               " | newSL=",DoubleToString(newSL,_Digits));
      }
      else
      {
         Print("ASLAN RECOVERY BE RETRY | ticket=",ticket,
               " | retcode=",rc," | ",trade.ResultRetcodeDescription(),
               " | net=",DoubleToString(net,2),
               " | requestedSL=",DoubleToString(newSL,_Digits));
      }
   }
}



//======================== v2.70 LIVE PROTECTION ====================
string TrimStr(string x)
{
   StringTrimLeft(x);
   StringTrimRight(x);
   return x;
}

//--- Ortalama spread (EMA) ve seans açılışı takibi, her tick
void UpdateLiveStats()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return;
   double sp=t.ask-t.bid;
   if(sp>0.0)
   {
      if(g_avgSpread<=0.0) g_avgSpread=sp;
      else
      {
         // Sıçramalar ortalamayı şişirmesin: ortalamaya en fazla 3 katı kadar katkı
         double capped=MathMin(sp,g_avgSpread*3.0);
         double alpha=2.0/(MathMax(10,SpreadAverageTicks)+1.0);
         g_avgSpread+=alpha*(capped-g_avgSpread);
      }
   }
   datetime now=TimeCurrent();
   if(g_lastTickTime==0 || now-g_lastTickTime>30*60)
      g_sessionOpen=now;                    // hafta açılışı veya günlük ara sonrası
   g_lastTickTime=now;
}

//--- Toplam lot (açık + bekleyen + yeni) sınırı ve marj seviyesi
bool ExposureAllows(double newLot)
{
   if(MinMarginLevelPercent>0.0)
   {
      double ml=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);   // pozisyon yoksa 0
      if(ml>0.0 && ml<MinMarginLevelPercent) return false;
   }
   if(MaxTotalLots<=0.0) return true;
   double lots=newLot;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(IsOurPosition(t)) lots+=PositionGetDouble(POSITION_VOLUME);
   }
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(IsOurOrder(t)) lots+=OrderGetDouble(ORDER_VOLUME_CURRENT);
   }
   return lots<=MaxTotalLots+1e-9;
}

//--- Ekonomik takvimden yüksek önemli haber saatlerini yükle (15 dk'da bir)
void LoadNews()
{
   if(!UseNewsFilter || MQLInfoInteger(MQL_TESTER)) return;
   datetime now=TimeTradeServer();
   if(g_lastNewsLoad>0 && now-g_lastNewsLoad<900) return;
   g_lastNewsLoad=now;

   if(ArraySize(g_newsCur)==0)
   {
      string parts[];
      int n=StringSplit(NewsCurrencies,',',parts);
      for(int i=0;i<n;i++)
      {
         string c=TrimStr(parts[i]);
         StringToUpper(c);
         if(c=="") continue;
         int k=ArraySize(g_newsCur);
         ArrayResize(g_newsCur,k+1);
         g_newsCur[k]=c;
      }
   }

   datetime fresh[];
   bool okAny=false;
   for(int c=0;c<ArraySize(g_newsCur);c++)
   {
      MqlCalendarValue values[];
      ResetLastError();
      if(!CalendarValueHistory(values,now-86400,now+2*86400,NULL,g_newsCur[c]))
      {
         Print("ASLAN NEWS LOAD FAILED | ",g_newsCur[c]," | err=",GetLastError());
         continue;
      }
      okAny=true;
      for(int i=0;i<ArraySize(values);i++)
      {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id,ev)) continue;
         if(ev.importance!=CALENDAR_IMPORTANCE_HIGH) continue;
         if(ev.time_mode!=CALENDAR_TIMEMODE_DATETIME) continue;
         int k=ArraySize(fresh);
         ArrayResize(fresh,k+1);
         fresh[k]=values[i].time;
      }
   }
   if(!okAny)
   {
      g_lastNewsLoad=now-840;               // 1 dk sonra tekrar dene, eski listeyi koru
      return;
   }
   ArrayResize(g_newsTimes,ArraySize(fresh));
   for(int i=0;i<ArraySize(fresh);i++) g_newsTimes[i]=fresh[i];
}

//--- Sunucu gece yarısından önceki rollover penceresinde miyiz?
bool InPreRollover()
{
   if(!UseRolloverFilter) return false;
   MqlDateTime d;
   TimeToStruct(TimeCurrent(),d);
   return (d.hour*60+d.min>=1440-RolloverMinutesBefore);
}

//--- Rollover öncesi açık pozisyonları kapat (swap ve günlük ara sonrası boşluk riski)
void CloseBeforeRolloverIfNeeded()
{
   if(!CloseBeforeRollover || !InPreRollover() || OurPositions()==0) return;
   Print("ASLAN ROLLOVER CLOSE | positions=",IntegerToString(OurPositions()),
         " | basket=",DoubleToString(OurFloatingNet(),2));
   CloseBasketPositionsOnly();
}

//--- Yeni bekleyen emir koymayı engelleyen durumları değerlendir
void EvaluateLiveBlock()
{
   string why="";
   MqlTick t;
   bool haveTick=SymbolInfoTick(_Symbol,t);
   double sp=haveTick ? t.ask-t.bid : 0.0;

   if(haveTick && sp/PT()>MaximumSpreadPoints)
      why=StringFormat("spread %.0f > max %.0f point",sp/PT(),MaximumSpreadPoints);
   else if(haveTick && SpreadSpikeMultiplier>0.0 && g_avgSpread>0.0 && sp>g_avgSpread*SpreadSpikeMultiplier)
      why=StringFormat("spread sicramasi %.0f (ort %.0f) point",sp/PT(),g_avgSpread/PT());

   datetime now=TimeCurrent();
   if(why=="" && UseRolloverFilter)
   {
      MqlDateTime d;
      TimeToStruct(now,d);
      int m=d.hour*60+d.min;
      if(m>=1440-RolloverMinutesBefore || m<RolloverMinutesAfter)
         why="rollover (sunucu gece yarisi)";
   }
   if(why=="" && SessionOpenSkipMinutes>0 && g_sessionOpen>0 && now-g_sessionOpen<SessionOpenSkipMinutes*60)
      why="piyasa acilisi / ara sonrasi";
   if(why=="" && UseNewsFilter)
   {
      for(int i=0;i<ArraySize(g_newsTimes);i++)
      {
         if(now>=g_newsTimes[i]-NewsMinutesBefore*60 && now<=g_newsTimes[i]+NewsMinutesAfter*60)
         {
            why="haber "+TimeToString(g_newsTimes[i],TIME_MINUTES);
            break;
         }
      }
   }
   if(why=="" && MinMarginLevelPercent>0.0)
   {
      double ml=AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      if(ml>0.0 && ml<MinMarginLevelPercent)
         why=StringFormat("marj seviyesi %.0f%%",ml);
   }

   bool wasBlocked=g_blocked;
   g_blocked=(why!="");
   g_blockReason=why;
   if(g_blocked && !wasBlocked)
      Print("ASLAN LIVE BLOCK ON | ",why);
   else if(!g_blocked && wasBlocked)
      Print("ASLAN LIVE BLOCK OFF");

   // Bekleyen stop emirleri spread sıçramasıyla tetiklenebilir: engel varken sil.
   if(g_blocked && DeletePendingWhenBlocked && OurPendingCount()>0)
   {
      Print("ASLAN PENDING REMOVED | ",why);
      DeleteOurPending();
   }
}

//--- Gerçekleşme günlüğü: istenen fiyat, gerçekleşen fiyat, kayma, spread, komisyon
void LogExecution(ulong deal)
{
   ulong  order    =(ulong)HistoryDealGetInteger(deal,DEAL_ORDER);
   double fill     =HistoryDealGetDouble(deal,DEAL_PRICE);
   double vol      =HistoryDealGetDouble(deal,DEAL_VOLUME);
   double comm     =HistoryDealGetDouble(deal,DEAL_COMMISSION);
   double profit   =HistoryDealGetDouble(deal,DEAL_PROFIT);
   ENUM_DEAL_TYPE  dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE);
   ENUM_DEAL_ENTRY de=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
   ENUM_DEAL_REASON dr=(ENUM_DEAL_REASON)HistoryDealGetInteger(deal,DEAL_REASON);

   double requested=0.0;
   if(order>0 && HistoryOrderSelect(order))
      requested=HistoryOrderGetDouble(order,ORDER_PRICE_OPEN);

   // Pozitif kayma = aleyhte (alışta daha pahalı, satışta daha ucuz)
   double slip=0.0;
   if(requested>0.0)
      slip=(fill-requested)*(dt==DEAL_TYPE_BUY ? 1.0 : -1.0)/PT();
   if(requested>0.0)
   {
      g_slipSum+=slip;
      g_slipCount++;
      if(slip>g_slipMax) g_slipMax=slip;
   }

   MqlTick t;
   double spread=SymbolInfoTick(_Symbol,t) ? (t.ask-t.bid)/PT() : 0.0;

   if(!LogExecutions) return;
   string name="ASLAN_exec_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN))+".csv";
   int h=FileOpen(name,FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ);
   if(h==INVALID_HANDLE) return;
   if(FileSize(h)==0)
      FileWriteString(h,"time,server,deal,side,entry,reason,volume,requested,fill,slip_points,spread_points,avg_spread_points,commission,profit\r\n");
   FileSeek(h,0,SEEK_END);
   FileWriteString(h,StringFormat("%s,%s,%I64u,%s,%s,%s,%.2f,%s,%s,%.1f,%.1f,%.1f,%.2f,%.2f\r\n",
                   TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                   AccountInfoString(ACCOUNT_SERVER),deal,
                   (dt==DEAL_TYPE_BUY?"BUY":"SELL"),
                   (de==DEAL_ENTRY_IN?"IN":"OUT"),
                   EnumToString(dr),vol,
                   DoubleToString(requested,_Digits),DoubleToString(fill,_Digits),
                   slip,spread,g_avgSpread/PT(),comm,profit));
   FileClose(h);
}

//------------------------ helpers ----------------------------------
double NormalizePrice(double p)
{
   return NormalizeDouble(p,(int)SymbolInfoInteger(_Symbol,SYMBOL_DIGITS));
}

double NormalizeVolume(double v)
{
   double mn=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double mx=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double st=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   if(mn<=0) mn=0.01;
   if(mx<=0) mx=100.0;
   if(st<=0) st=mn;
   v=MathMax(mn,MathMin(mx,v));
   v=MathFloor(v/st+1e-9)*st;
   int d=(st>=1.0?0:(st>=0.1?1:2));
   return NormalizeDouble(MathMax(mn,v),d);
}

double SpreadPoints()
{
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return 1e9;
   return (t.ask-t.bid)/PT();
}

bool IsOurOrder(ulong ticket)
{
   if(ticket==0 || !OrderSelect(ticket)) return false;
   return OrderGetString(ORDER_SYMBOL)==_Symbol &&
          (long)OrderGetInteger(ORDER_MAGIC)==MagicNumber;
}

bool IsOurPosition(ulong ticket)
{
   if(ticket==0 || !PositionSelectByTicket(ticket)) return false;
   return PositionGetString(POSITION_SYMBOL)==_Symbol &&
          (long)PositionGetInteger(POSITION_MAGIC)==MagicNumber;
}

int OurPositions()
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(IsOurPosition(t)) n++;
   }
   return n;
}

int OurPendingCount()
{
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(IsOurOrder(t)) n++;
   }
   return n;
}

double OurFloatingNet()
{
   // TOTAL basket net = BUY + SELL floating profit + swap +
   // already charged commission for every open position.
   // This is the primary number used by the basket profit protector.
   double x=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!IsOurPosition(t)) continue;
      double profit=PositionGetDouble(POSITION_PROFIT);
      double swap=PositionGetDouble(POSITION_SWAP);
      double commission=PositionCommissionForSelectedPosition();
      x += profit + swap + commission;
   }
   return x;
}

int DayKey()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(),d);
   return d.year*10000+d.mon*100+d.day;
}

double TodayNet()
{
   MqlDateTime d;
   TimeToStruct(TimeCurrent(),d);
   d.hour=0; d.min=0; d.sec=0;
   datetime from=StructToTime(d), now=TimeCurrent();
   if(!HistorySelect(from,now)) return 0.0;

   double x=0.0;
   int n=HistoryDealsTotal();
   for(int i=0;i<n;i++)
   {
      ulong t=HistoryDealGetTicket(i);
      if(!t) continue;
      if(HistoryDealGetString(t,DEAL_SYMBOL)!=_Symbol) continue;
      if((long)HistoryDealGetInteger(t,DEAL_MAGIC)!=MagicNumber) continue;
      ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(t,DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_OUT_BY) continue;
      x += HistoryDealGetDouble(t,DEAL_PROFIT);
      x += HistoryDealGetDouble(t,DEAL_SWAP);
      x += HistoryDealGetDouble(t,DEAL_COMMISSION);
   }
   return x;
}

void DeleteOurPending()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(IsOurOrder(t))
         trade.OrderDelete(t);
   }
}

void CloseOurPositions()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(IsOurPosition(t))
         trade.PositionClose(t);
   }
}

void EndCycle()
{
   DeleteOurPending();
   CloseOurPositions();
   gridCenterPrice=0.0;
   cycleActive=false;
}

double LevelDistancePrice()
{
   double d=GridDistancePoints*PT();
   if(ScaleSpacingByPrice)
   {
      double scaled=SymbolInfoDouble(_Symbol,SYMBOL_BID)*PriceScalePercent/100.0;
      d=MathMax(_Point*5.0,MathMin(d,scaled));
   }
   // v2.70: grid aralığı ortalama spread'in katından küçük olamaz
   if(GridSpreadMultiplier>0.0 && g_avgSpread>0.0)
      d=MathMax(d,TradingCostPrice()*GridSpreadMultiplier);
   return d;
}

//--- v2.70: SL mesafesi (fiyat birimi), ortalama spread'in katından küçük olamaz
double SLDistancePrice()
{
   double d=InitialSLPoints*PT();
   if(SLSpreadMultiplier>0.0 && g_avgSpread>0.0)
      d=MathMax(d,TradingCostPrice()*SLSpreadMultiplier);
   return d;
}

double AutoBalanceLot()
{
   if(!UseAutomaticBalanceLot)
      return NormalizeVolume(ManualLot);

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double stepMoney=MathMax(1.0,BalanceStepMoney);
   double lotStep=MathMax(0.0001,LotStepPerBalance);
   int steps=(int)MathFloor(balance/stepMoney+1e-9);
   double lot=MathMax(lotStep,steps*lotStep);
   lot=MathMin(lot,MaximumAutoLot);
   return NormalizeVolume(lot);
}

double LotForLevel(int level)
{
   // Keep all grid legs at the balance-derived base lot.
   // This prevents deep levels from multiplying commission and risk.
   return AutoBalanceLot();
}

bool PendingNear(ENUM_ORDER_TYPE type,double price,double tolerancePoints=5.0)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(!IsOurOrder(t)) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)!=type) continue;
      double p=OrderGetDouble(ORDER_PRICE_OPEN);
      if(MathAbs(p-price)<=tolerancePoints*PT()) return true;
   }
   return false;
}

double PositionCommissionForSelectedPosition()
{
   ulong position_id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(position_id==0) return 0.0;

   // v2.70: açılış komisyonu pozisyon boyunca sabittir; her tick'te geçmişi
   // taramak yerine önbellekten oku (canlıda gecikmeyi azaltır).
   double commission=0.0;
   bool cached=false;
   for(int c=0;c<ArraySize(g_commId);c++)
      if(g_commId[c]==position_id){ commission=g_commVal[c]; cached=true; break; }

   if(!cached)
   {
      if(!HistorySelectByPosition(position_id)) return 0.0;
      int total=HistoryDealsTotal();
      for(int i=0;i<total;i++)
      {
         ulong deal_ticket=HistoryDealGetTicket(i);
         if(deal_ticket==0) continue;
         commission += HistoryDealGetDouble(deal_ticket,DEAL_COMMISSION);
      }
      int k=ArraySize(g_commId);
      ArrayResize(g_commId,k+1);
      ArrayResize(g_commVal,k+1);
      g_commId[k]=position_id;
      g_commVal[k]=commission;
   }

   // v2.70: ECN hesapta kapanışta da komisyon kesilir; net hedefler bunu içersin
   if(CountClosingCommission) commission*=2.0;
   return commission;
}

double PositionNetProfit()
{
   double p=PositionGetDouble(POSITION_PROFIT);
   p+=PositionGetDouble(POSITION_SWAP);
   p+=PositionCommissionForSelectedPosition();
   return p;
}

bool PlaceStop(ENUM_ORDER_TYPE type,double price,double lot,int level)
{
   if(g_blocked) return false;                       // v2.70: spread/rollover/haber/marj engeli
   if(SpreadPoints()>MaximumSpreadPoints) return false;
   if(OurPositions()>=MaximumPositions) return false;
   if(!ExposureAllows(lot)) return false;            // v2.70: toplam lot sınırı

   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return false;

   double minDist=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double freeze=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*_Point;
   minDist=MathMax(MathMax(minDist,freeze),2.0*_Point);

   if(type==ORDER_TYPE_BUY_STOP)
      price=MathMax(price,t.ask+minDist);
   else
      price=MathMin(price,t.bid-minDist);

   price=NormalizePrice(price);
   lot=NormalizeVolume(lot);
   if(PendingNear(type,price,3.0)) return true;

   double sl=0.0;
   if(UseInitialSL && InitialSLPoints>0.0)
   {
      if(type==ORDER_TYPE_BUY_STOP)
      {
         sl=price-SLDistancePrice();
         sl=MathMin(sl,t.bid-minDist);
      }
      else
      {
         sl=price+SLDistancePrice();
         sl=MathMax(sl,t.ask+minDist);
      }
      sl=NormalizePrice(sl);
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   string side=(type==ORDER_TYPE_BUY_STOP ? "BUY" : "SELL");
   string comment="ASLAN_VK_"+side+"_L"+IntegerToString(level);
   bool ok=false;
   if(type==ORDER_TYPE_BUY_STOP)
      ok=trade.BuyStop(lot,price,_Symbol,sl,0.0,ORDER_TIME_GTC,0,comment);
   else
      ok=trade.SellStop(lot,price,_Symbol,sl,0.0,ORDER_TIME_GTC,0,comment);

   if(ok)
      Print("ASLAN GRID ADD | ",comment," | price=",DoubleToString(price,_Digits),
            " | lot=",DoubleToString(lot,2));
   else
      Print("ASLAN GRID ADD FAILED | ",comment," | ",trade.ResultRetcode()," | ",trade.ResultRetcodeDescription());
   return ok;
}

int PendingCountByType(ENUM_ORDER_TYPE type)
{
   int n=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(!IsOurOrder(t)) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)==type) n++;
   }
   return n;
}

double ExtremePendingPrice(ENUM_ORDER_TYPE type)
{
   double extreme=0.0;
   bool have=false;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong t=OrderGetTicket(i);
      if(!IsOurOrder(t)) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)!=type) continue;
      double p=OrderGetDouble(ORDER_PRICE_OPEN);
      if(!have){ extreme=p; have=true; }
      else if(type==ORDER_TYPE_BUY_STOP) extreme=MathMax(extreme,p);
      else extreme=MathMin(extreme,p);
   }
   return have?extreme:0.0;
}

double ExtremePositionPrice(ENUM_POSITION_TYPE type)
{
   double extreme=0.0;
   bool have=false;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong t=PositionGetTicket(i);
      if(!IsOurPosition(t)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=type) continue;
      double p=PositionGetDouble(POSITION_PRICE_OPEN);
      if(!have){ extreme=p; have=true; }
      else if(type==POSITION_TYPE_BUY) extreme=MathMax(extreme,p);
      else extreme=MathMin(extreme,p);
   }
   return have?extreme:0.0;
}

void DeletePendingByType(ENUM_ORDER_TYPE type)
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      ulong ticket=OrderGetTicket(i);
      if(!IsOurOrder(ticket)) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)!=type) continue;
      trade.SetExpertMagicNumber(MagicNumber);
      if(!trade.OrderDelete(ticket))
         Print("ASLAN OPPOSITE PENDING DELETE FAILED | ticket=",ticket,
               " | ",trade.ResultRetcode()," | ",trade.ResultRetcodeDescription());
   }
}

void SetActiveGridDirection(int dir,double anchor)
{
   if(!UseActiveDirectionMode) return;
   if(dir>0) dir=1; else if(dir<0) dir=-1; else dir=0;
   if(dir==0) return;

   activeGridDirection=dir;
   directionAnchorPrice=anchor;

   if(CancelOppositePendingOnSwitch)
   {
      if(dir>0)
         DeletePendingByType(ORDER_TYPE_SELL_STOP);
      else
         DeletePendingByType(ORDER_TYPE_BUY_STOP);
   }

   Print("ASLAN ACTIVE GRID DIRECTION | ",(dir>0?"BUY":"SELL"),
         " | anchor=",DoubleToString(anchor,_Digits));
}

void DetectActiveDirection()
{
   if(!UseActiveDirectionMode) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return;

   // If there are no positions, start neutral so both sides can seed again.
   if(OurPositions()==0)
   {
      activeGridDirection=0;
      directionAnchorPrice=0.0;
      return;
   }

   // A newly active side establishes direction. If both sides are already
   // open, keep the current state rather than flip on every tick.
   if(activeGridDirection==0)
   {
      int buys=0,sells=0;
      for(int i=PositionsTotal()-1;i>=0;i--)
      {
         ulong ticket=PositionGetTicket(i);
         if(!IsOurPosition(ticket)) continue;
         ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(pt==POSITION_TYPE_BUY) buys++;
         else if(pt==POSITION_TYPE_SELL) sells++;
      }
      if(buys>0 && sells==0) SetActiveGridDirection(1,t.bid);
      else if(sells>0 && buys==0) SetActiveGridDirection(-1,t.ask);
      else return;
   }

   double trigger=MathMax(1.0,DirectionSwitchPoints)*PT();
   if(activeGridDirection<0)
   {
      // SELL mode: a meaningful upward move signals BUY reversal.
      if(directionAnchorPrice>0.0 && t.ask>=directionAnchorPrice+trigger)
         SetActiveGridDirection(1,t.ask);
   }
   else if(activeGridDirection>0)
   {
      // BUY mode: a meaningful downward move signals SELL reversal.
      if(directionAnchorPrice>0.0 && t.bid<=directionAnchorPrice-trigger)
         SetActiveGridDirection(-1,t.bid);
   }
}

void EnsureSideGrid(ENUM_ORDER_TYPE type)
{
   if((type==ORDER_TYPE_BUY_STOP && !AllowBuy) ||
      (type==ORDER_TYPE_SELL_STOP && !AllowSell))
      return;

   const int maxPending=MathMax(1,MaxPendingPerSide);
   int pending=PendingCountByType(type);
   if(pending>=maxPending) return;

   double d=LevelDistancePrice();
   if(d<=0.0) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return;

   // When a side has no pending orders at all, seed a complete window.
   // This is used at startup or after a side was fully consumed/cancelled.
   if(pending==0)
   {
      double anchor=(type==ORDER_TYPE_BUY_STOP ? t.ask : t.bid);

      // If positions of this side already exist, continue from the
      // furthest active position instead of rebuilding around price.
      double posExtreme=ExtremePositionPrice(
         type==ORDER_TYPE_BUY_STOP ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

      if(posExtreme>0.0)
         anchor=(type==ORDER_TYPE_BUY_STOP ? MathMax(anchor,posExtreme)
                                           : MathMin(anchor,posExtreme));

      for(int level=1; level<=maxPending; level++)
      {
         double price=(type==ORDER_TYPE_BUY_STOP ?
                       anchor+d*level : anchor-d*level);

         if(!PlaceStop(type,price,AutoBalanceLot(),level))
            break;
      }
      return;
   }

   // Persistent replenishment:
   // - NEVER delete existing pending orders.
   // - NEVER move existing pending orders.
   // - Add only the missing orders beyond the furthest existing
   //   pending/position in the same direction.
   // This lets a one-way rally keep generating fresh entries.
   while(pending<maxPending)
   {
      double extremePending=ExtremePendingPrice(type);
      double extremePos=ExtremePositionPrice(
         type==ORDER_TYPE_BUY_STOP ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

      double base;
      if(type==ORDER_TYPE_BUY_STOP)
      {
         base=MathMax(t.ask,MathMax(extremePending,extremePos));
         double price=NormalizePrice(base+d);

         // New BUY STOP must be above the current ASK and also beyond
         // the furthest existing BUY level.
         if(extremePending>0.0 &&
            price<=extremePending+ReplenishMinMovePoints*PT())
            break;

         if(!PlaceStop(type,price,AutoBalanceLot(),pending+1))
            break;
      }
      else
      {
         if(extremePending>0.0 && extremePos>0.0)
            base=MathMin(t.bid,MathMin(extremePending,extremePos));
         else if(extremePending>0.0)
            base=MathMin(t.bid,extremePending);
         else if(extremePos>0.0)
            base=MathMin(t.bid,extremePos);
         else
            base=t.bid;

         double price=NormalizePrice(base-d);

         // New SELL STOP must be below the current BID and beyond the
         // furthest existing SELL level.
         if(extremePending>0.0 &&
            price>=extremePending-ReplenishMinMovePoints*PT())
            break;

         if(!PlaceStop(type,price,AutoBalanceLot(),pending+1))
            break;
      }

      pending++;
   }
}


void MaintainPersistentGrid()
{
   if(!StartWithBuySellStops) return;
   if(g_blocked) return;
   if(SpreadPoints()>MaximumSpreadPoints) return;

   if(!UseActiveDirectionMode)
   {
      // Legacy persistent two-sided mode.
      if(AllowBuy)  EnsureSideGrid(ORDER_TYPE_BUY_STOP);
      if(AllowSell) EnsureSideGrid(ORDER_TYPE_SELL_STOP);
   }
   else
   {
      DetectActiveDirection();

      if(activeGridDirection==0)
      {
         // At startup/after a completely flat basket, seed both directions.
         if(AllowBuy)  EnsureSideGrid(ORDER_TYPE_BUY_STOP);
         if(AllowSell) EnsureSideGrid(ORDER_TYPE_SELL_STOP);
      }
      else if(activeGridDirection>0)
      {
         // BUY mode: only replenish BUY stops. SELL pending orders are removed
         // when the direction was established or reversed.
         if(AllowBuy) EnsureSideGrid(ORDER_TYPE_BUY_STOP);
      }
      else
      {
         // SELL mode: only replenish SELL stops.
         if(AllowSell) EnsureSideGrid(ORDER_TYPE_SELL_STOP);
      }
   }

   if(OurPositions()>0 || OurPendingCount()>0)
      cycleActive=true;
}

void BuildGridIfNeeded()
{
   MaintainPersistentGrid();
}

void ApplyInitialSLToPositions()
{
   if(!UseInitialSL || InitialSLPoints<=0) return;

   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return;

   double stopLevel=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double freeze=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*_Point;
   double minDist=MathMax(stopLevel,freeze)+2.0*_Point;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!IsOurPosition(ticket)) continue;

      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double oldSL=PositionGetDouble(POSITION_SL);
      if(oldSL>0.0) continue;

      double sl=0.0;
      if(type==POSITION_TYPE_BUY)
      {
         sl=entry-SLDistancePrice();
         // Never submit an invalid SL. If the broker requires more room,
         // widen the SL to the nearest valid price.
         if(sl>t.bid-minDist) sl=t.bid-minDist;
      }
      else
      {
         sl=entry+SLDistancePrice();
         if(sl<t.ask+minDist) sl=t.ask+minDist;
      }
      sl=NormalizePrice(sl);

      trade.SetExpertMagicNumber(MagicNumber);
      if(!trade.PositionModify(ticket,sl,PositionGetDouble(POSITION_TP)))
         Print("ASLAN INITIAL SL FAILED | ticket=",ticket," | ",trade.ResultRetcode()," | ",trade.ResultRetcodeDescription());
      else
         Print("ASLAN INITIAL SL | ticket=",ticket," | SL=",DoubleToString(sl,_Digits));
   }
}

double GrossProfitAtStop(ENUM_POSITION_TYPE type,double volume,double entry,double stopPrice)
{
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   double profit=0.0;
   if(!OrderCalcProfit(ot,_Symbol,volume,entry,stopPrice,profit)) return -1e100;
   return profit;
}

double StopPriceForNetLock(ENUM_POSITION_TYPE type,double volume,double entry,double currentPrice,
                           double swap,double commission,double targetNet)
{
   double targetGross=targetNet-swap-commission;
   if(type==POSITION_TYPE_BUY)
   {
      if(targetGross<=0.0) return entry;
      double lo=entry, hi=currentPrice;
      if(GrossProfitAtStop(type,volume,entry,hi)<targetGross) return 0.0;
      for(int k=0;k<50;k++)
      {
         double mid=(lo+hi)*0.5;
         if(GrossProfitAtStop(type,volume,entry,mid)>=targetGross) hi=mid; else lo=mid;
      }
      return hi;
   }
   if(type==POSITION_TYPE_SELL)
   {
      if(targetGross<=0.0) return entry;
      double lo=currentPrice, hi=entry;
      if(GrossProfitAtStop(type,volume,entry,lo)<targetGross) return 0.0;
      for(int k=0;k<50;k++)
      {
         double mid=(lo+hi)*0.5;
         if(GrossProfitAtStop(type,volume,entry,mid)>=targetGross) lo=mid; else hi=mid;
      }
      return lo;
   }
   return 0.0;
}

bool IsLockStopValid(ENUM_POSITION_TYPE type,double sl,const MqlTick &t,double minDist)
{
   if(sl<=0.0) return false;
   if(type==POSITION_TYPE_BUY) return sl <= t.bid-minDist+1e-10;
   if(type==POSITION_TYPE_SELL) return sl >= t.ask+minDist-1e-10;
   return false;
}

void ManageTrailing()
{
   if(!UsePerLegTrailing) return;
   MqlTick t;
   if(!SymbolInfoTick(_Symbol,t)) return;
   double stopLevel=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)*_Point;
   double freeze=(double)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL)*_Point;
   double minDist=MathMax(stopLevel,freeze)+2.0*_Point;

   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!IsOurPosition(ticket)) continue;
      ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double oldSL=PositionGetDouble(POSITION_SL);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double swap=PositionGetDouble(POSITION_SWAP);
      double commission=PositionCommissionForSelectedPosition();
      double net=PositionNetProfit();
      if(TrailProfitableLegsOnly && net<TrailArmMoney) continue;

      double currentPrice=(type==POSITION_TYPE_BUY ? t.bid : t.ask);
      double newSL=StopPriceForNetLock(type,volume,entry,currentPrice,swap,commission,TrailLockMoney);
      if(newSL<=0.0)
      {
         Print("ASLAN TRAIL WAIT | ticket=",ticket," | net=",DoubleToString(net,2)," | targetLock=",DoubleToString(TrailLockMoney,2));
         continue;
      }
      newSL=NormalizePrice(newSL);

      if(type==POSITION_TYPE_BUY)
      {
         double trailSL=NormalizePrice(MathMin(currentPrice-TrailDistancePoints*PT(),currentPrice-minDist));
         if(IsLockStopValid(type,trailSL,t,minDist) && trailSL>newSL) newSL=trailSL;
         if(oldSL>0.0 && newSL<=oldSL) continue;
         if(oldSL>0.0 && (newSL-oldSL)/PT()<TrailStepPoints) continue;
      }
      else if(type==POSITION_TYPE_SELL)
      {
         double trailSL=NormalizePrice(MathMax(currentPrice+TrailDistancePoints*PT(),currentPrice+minDist));
         if(IsLockStopValid(type,trailSL,t,minDist) && trailSL<newSL) newSL=trailSL;
         if(oldSL>0.0 && newSL>=oldSL) continue;
         if(oldSL>0.0 && (oldSL-newSL)/PT()<TrailStepPoints) continue;
      }
      else continue;

      if(!IsLockStopValid(type,newSL,t,minDist)) continue;
      trade.SetExpertMagicNumber(MagicNumber);
      ResetLastError();
      bool ok=trade.PositionModify(ticket,newSL,PositionGetDouble(POSITION_TP));
      uint rc=trade.ResultRetcode();
      if(ok && (rc==TRADE_RETCODE_DONE || rc==TRADE_RETCODE_DONE_PARTIAL || rc==TRADE_RETCODE_PLACED))
      {
         trailLockActive=true;
         Print("ASLAN TRAILLOCK OK | ticket=",ticket," | net=",DoubleToString(net,2)," | lock=",DoubleToString(TrailLockMoney,2)," | oldSL=",DoubleToString(oldSL,_Digits)," | newSL=",DoubleToString(newSL,_Digits));
         if(StopNewGridAfterLock) DeleteOurPending();
      }
      else
      {
         Print("ASLAN TRAILLOCK RETRY | ticket=",ticket," | retcode=",rc," | ",trade.ResultRetcodeDescription()," | net=",DoubleToString(net,2)," | requestedSL=",DoubleToString(newSL,_Digits));
      }
   }
}
double BasketNetAtCommonStop(ENUM_POSITION_TYPE type,double stopPrice)
{
   double total=0.0;
   ENUM_ORDER_TYPE ot=(type==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!IsOurPosition(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=type) continue;
      double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double volume=PositionGetDouble(POSITION_VOLUME);
      double swap=PositionGetDouble(POSITION_SWAP);
      double commission=PositionCommissionForSelectedPosition();
      double gross=0.0;
      if(!OrderCalcProfit(ot,_Symbol,volume,entry,stopPrice,gross)) return -1e100;
      total += gross+swap+commission;
   }
   return total;
}

double CommonStopForBasketNetLock(ENUM_POSITION_TYPE type,double targetNet,const MqlTick &t,double minDist)
{
   int n=0;
   double minEntry=0.0,maxEntry=0.0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!IsOurPosition(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)!=type) continue;
      double e=PositionGetDouble(POSITION_PRICE_OPEN);
      if(n==0){minEntry=e;maxEntry=e;} else {minEntry=MathMin(minEntry,e);maxEntry=MathMax(maxEntry,e);} n++;
   }
   if(n==0) return 0.0;

   double current=(type==POSITION_TYPE_BUY?t.bid:t.ask);
   double brokerLimit=(type==POSITION_TYPE_BUY?t.bid-minDist:t.ask+minDist);
   if(type==POSITION_TYPE_BUY)
   {
      double hi=brokerLimit;
      double lo=MathMin(minEntry,hi)-5000.0*_Point;
      if(BasketNetAtCommonStop(type,hi)<targetNet) return 0.0;
      for(int k=0;k<60;k++)
      {
         double mid=(lo+hi)*0.5;
         if(BasketNetAtCommonStop(type,mid)>=targetNet) lo=mid; else hi=mid;
      }
      return NormalizePrice(lo);
   }
   else
   {
      double lo=brokerLimit;
      double hi=MathMax(maxEntry,lo)+5000.0*_Point;
      if(BasketNetAtCommonStop(type,lo)<targetNet) return 0.0;
      for(int k=0;k<60;k++)
      {
         double mid=(lo+hi)*0.5;
         if(BasketNetAtCommonStop(type,mid)>=targetNet) hi=mid; else lo=mid;
      }
      return NormalizePrice(hi);
   }
}

void CloseBasketPositionsOnly()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong ticket=PositionGetTicket(i);
      if(!IsOurPosition(ticket)) continue;
      trade.SetExpertMagicNumber(MagicNumber);
      ResetLastError();
      bool ok=trade.PositionClose(ticket);
      uint rc=trade.ResultRetcode();
      if(!ok || (rc!=TRADE_RETCODE_DONE && rc!=TRADE_RETCODE_DONE_PARTIAL && rc!=TRADE_RETCODE_PLACED))
         Print("ASLAN BASKET CLOSE RETRY | ticket=",ticket," | retcode=",rc," | ",trade.ResultRetcodeDescription());
      else
         Print("ASLAN BASKET CLOSE OK | ticket=",ticket);
   }
}

void ManageCommonBasketTrail()
{
   if(!UseBasketMoneyTrail) return;

   int n=OurPositions();
   if(n<=0)
   {
      // A new basket starts with a fresh peak.
      totalBasketPeak=0.0;
      totalBasketTrailArmed=false;
      return;
   }

   // IMPORTANT: use ALL open positions together. Do not split BUY and SELL.
   // This matches the requested basket behavior and prevents a profitable
   // mixed basket from being ignored because neither side is profitable alone.
   double basket=OurFloatingNet();

   if(!totalBasketTrailArmed)
   {
      if(basket < BasketTrailStartMoney) return;
      totalBasketTrailArmed=true;
      totalBasketPeak=basket;
      Print("ASLAN TOTAL BASKET TRAIL ARMED | basket=",DoubleToString(basket,2));
   }
   else
   {
      if(basket>totalBasketPeak)
         totalBasketPeak=basket;
   }

   double protectedNet=totalBasketPeak-BasketTrailGivebackMoney;
   if(protectedNet<=0.0) return;

   // Software close is the primary protection. This is intentionally not
   // dependent on broker-side SL placement because a mixed BUY+SELL basket
   // cannot be represented by one common SL price.
   if(CloseBasketOnTrailHit && basket<=protectedNet+0.01)
   {
      Print("ASLAN TOTAL BASKET TRAIL HIT | peak=",DoubleToString(totalBasketPeak,2),
            " | protected=",DoubleToString(protectedNet,2),
            " | current=",DoubleToString(basket,2),
            " | positions=",IntegerToString(n));

      CloseBasketPositionsOnly();

      // Keep the peak until all positions are actually gone. If a close
      // request is rejected, the next tick retries instead of losing state.
      if(OurPositions()==0)
      {
         totalBasketPeak=0.0;
         totalBasketTrailArmed=false;
      }
      return;
   }
}

bool RiskAndDaily()
{
   int today=DayKey();
   if(today!=lockedDay){ lockedDay=today; dailyLocked=false; }
   if(dailyLocked) return false;

   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);

   if(UseEquityDDLimit && balance>0.0)
   {
      double dd=(balance-equity)/balance*100.0;
      if(dd>=MaximumDrawdownPercent)
      {
         Print("ASLAN HARD DD LIMIT | ",DoubleToString(dd,2),"%");
         EndCycle();
         dailyLocked=true;
         return false;
      }
   }

   double day=TodayNet()+OurFloatingNet();
   if(UseDailyNetTarget && day>=DailyNetTarget)
   {
      Print("ASLAN DAILY TARGET | ",DoubleToString(day,2));
      EndCycle(); dailyLocked=true; return false;
   }
   if(UseDailyNetLossLimit && day<=-MathAbs(DailyNetLossLimit))
   {
      Print("ASLAN DAILY LOSS LIMIT | ",DoubleToString(day,2));
      EndCycle(); dailyLocked=true; return false;
   }
   return true;
}

void ManageTargets()
{
   if(!cycleActive) return;
   double f=OurFloatingNet();

   if(UseCycleNetBankTarget && f>=CycleNetBankTarget)
   {
      Print("ASLAN CYCLE BANK | ",DoubleToString(f,2));
      EndCycle();
      return;
   }
   if(UseWholeBookGreenBank && f>=WholeBookGreenTarget)
   {
      Print("ASLAN WHOLE BOOK BANK | ",DoubleToString(f,2));
      EndCycle();
      return;
   }
   if(OurPositions()==0 && OurPendingCount()==0)
   {
      cycleActive=false;
      gridCenterPrice=0.0;
   }
}

int OnInit()
{
   g_scale=(AutoScalePoints && (_Digits==3 || _Digits==5)) ? 10.0 : 1.0;
   Print("ASLAN POINT SCALE | digits=",_Digits," | scale=",DoubleToString(g_scale,0),
         " | stopLevel=",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
         " | freezeLevel=",SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL));
   if(UseNewsFilter && MQLInfoInteger(MQL_TESTER))
      Print("ASLAN NOTE | Strategy Tester'da ekonomik takvim calismaz; haber filtresi bu testte etkisiz.");
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   Print("ASLAN v2.70 INIT | ",_Symbol," | Magic=",MagicNumber," | Chart=",EnumToString((ENUM_TIMEFRAMES)_Period));
   UpdateMemo();
   return INIT_SUCCEEDED;
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                         const MqlTradeRequest& request,
                         const MqlTradeResult& result)
{
   if(trans.type!=TRADE_TRANSACTION_DEAL_ADD) return;
   ulong deal=trans.deal;
   if(deal==0) return;
   if(HistoryDealGetString(deal,DEAL_SYMBOL)!=_Symbol) return;
   if((long)HistoryDealGetInteger(deal,DEAL_MAGIC)!=MagicNumber) return;

   ENUM_DEAL_ENTRY e=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal,DEAL_ENTRY);
   ENUM_DEAL_TYPE dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(deal,DEAL_TYPE);
   if(dt==DEAL_TYPE_BUY || dt==DEAL_TYPE_SELL)
      LogExecution(deal);

   if(e==DEAL_ENTRY_IN || e==DEAL_ENTRY_INOUT)
   {
      Print("ASLAN ENTRY | price=",DoubleToString(HistoryDealGetDouble(deal,DEAL_PRICE),_Digits),
            " | volume=",DoubleToString(HistoryDealGetDouble(deal,DEAL_VOLUME),2));

      // The first triggered side becomes the active direction. Opposite
      // pending orders are cancelled so stale levels cannot trigger later.
      double entryPrice=HistoryDealGetDouble(deal,DEAL_PRICE);
      if(dt==DEAL_TYPE_BUY)
      {
         SetActiveGridDirection(1,entryPrice);
         EnsureSideGrid(ORDER_TYPE_BUY_STOP);
      }
      else if(dt==DEAL_TYPE_SELL)
      {
         SetActiveGridDirection(-1,entryPrice);
         EnsureSideGrid(ORDER_TYPE_SELL_STOP);
      }
   }
   else if(e==DEAL_ENTRY_OUT || e==DEAL_ENTRY_OUT_BY)
   {
      // A slot became free after a close. Refill only the active direction.
      // When the basket becomes fully flat, the next tick returns to neutral
      // and seeds both directions again.
      MaintainPersistentGrid();
   }
}

void UpdateMemo()
{
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double lot=AutoBalanceLot();
   string tf=(_Period==PERIOD_M5 ? "M5 OK" : "USE M5");
   Comment("ASLAN VUR-KAC v2.70 LIVE\n",
           "Recommended: XAUUSD M5 | ",tf,"\n",
           "Balance: ",DoubleToString(balance,2),
           " | Equity: ",DoubleToString(equity,2),"\n",
           "Auto Lot: ",DoubleToString(lot,2),
           " | Positions: ",IntegerToString(OurPositions()),
           " | Pending: ",IntegerToString(OurPendingCount()),"\n",
           "Active-direction grid: ON | Replenish: ON\n",
           "TOTAL basket trail: ",UseBasketMoneyTrail?"ON":"OFF", " | Start=",DoubleToString(BasketTrailStartMoney,2),
           " | Giveback=",DoubleToString(BasketTrailGivebackMoney,2),
           " | Peak=",DoubleToString(totalBasketPeak,2),"\n",
           "Spread: ",DoubleToString(SpreadPoints(),0)," | Avg: ",DoubleToString(g_avgSpread/PT(),1),
           " | Cost: ",DoubleToString(TradingCostPrice()/PT(),1),
           " | Grid: ",DoubleToString(LevelDistancePrice()/PT(),0)," | SL: ",DoubleToString(SLDistancePrice()/PT(),0)," point\n",
           "Slippage avg: ",DoubleToString(g_slipCount>0?g_slipSum/g_slipCount:0.0,1),
           " | max: ",DoubleToString(g_slipMax,1)," point (",IntegerToString(g_slipCount)," fill)\n",
           "Live block: ",(g_blocked?g_blockReason:"yok"));
}

void OnTick()
{
   UpdateLiveStats();
   LoadNews();
   UpdateMemo();
   if(!RiskAndDaily()) return;
   EvaluateLiveBlock();
   CloseBeforeRolloverIfNeeded();

   ApplyInitialSLToPositions();
   ManageTargets();
   ManageRecoveryBreakEven();
   ManageTrailing();
   ManageCommonBasketTrail();

   if(OurPositions()>0) cycleActive=true;

   // Direction management runs every tick so a genuine reversal can cancel
   // stale opposite pending orders and re-arm the new active side.
   MaintainPersistentGrid();

   if(OurPositions()==0 && OurPendingCount()==0)
   {
      trailLockActive=false;
      cycleActive=false;
      activeGridDirection=0;
      directionAnchorPrice=0.0;
      ArrayResize(g_commId,0);              // komisyon önbelleğini temizle
      ArrayResize(g_commVal,0);
      MaintainPersistentGrid();
   }
}

void OnDeinit(const int reason)
{
   Comment("");
   Print("ASLAN v2.70 DEINIT | reason=",reason);
}
//+------------------------------------------------------------------+
