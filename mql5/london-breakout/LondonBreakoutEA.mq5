//+------------------------------------------------------------------+
//|                                             LondonBreakoutEA.mq5 |
//|  XAUUSD M5 - Londra açılış kırılımı (Asya aralığı)               |
//|                                                                  |
//|  Kurallar (sunucu saati, EC Markets GMT+2/+3):                   |
//|  1) 01:00-10:00 arası M5 mumlarının en yüksek/en düşüğü = aralık |
//|  2) 10:00'da aralığın üstüne Buy Stop, altına Sell Stop koyulur  |
//|     (tampon InpBufferPoints). Biri dolunca diğeri silinir (OCO). |
//|  3) SL = 3 x ATR(14, M5), TP = 2R. Günde en fazla 1 işlem.       |
//|  4) 14:00'a kadar dolmayan emirler silinir, açık pozisyon 19:00'da|
//|     kapatılır.                                                   |
//|  Martingale / grid / averaging YOK. Her işlem SL + TP ile açılır.|
//+------------------------------------------------------------------+
#property copyright "LondonBreakoutEA"
#property version   "1.00"
#property description "XAUUSD M5 Londra açılış kırılımı: Asya aralığı (01-10 sunucu) kırılımında stop emri,"
#property description "SL 3xATR(14), TP 2R, günde 1 işlem, 14:00'da bekleyen emir iptal, 19:00'da kapanış."

#include <Trade\Trade.mqh>

input group "=== Genel ==="
input ulong  InpMagic            = 20261009;  // Magic number
input double InpRiskPercent      = 0.5;       // İşlem başı risk (% bakiye)
input double InpFixedLot         = 0.0;       // Sabit lot (0 = risk yüzdesi kullan)

input group "=== Saatler (sunucu saati) ==="
input int    InpRangeStartHour   = 1;         // Asya aralığı başlangıcı
input int    InpRangeEndHour     = 10;        // Aralık bitişi = emirlerin konduğu saat (Londra açılışı)
input int    InpTradeEndHour     = 14;        // Bu saate kadar dolmayan emirler silinir
input int    InpExitHour         = 19;        // Açık pozisyon bu saatte kapatılır

input group "=== Giriş / Çıkış ==="
input double InpBufferPoints     = 5.0;       // Aralık dışına tampon (point)
input int    InpATRPeriod        = 14;        // ATR periyodu (M5)
input double InpSLATRMult        = 3.0;       // SL = ATR x çarpan
input double InpTPRR             = 2.0;       // TP = SL x oran
input bool   InpAllowBuy         = true;      // Alış izni
input bool   InpAllowSell        = true;      // Satış izni
input int    InpMinRangeBars     = 12;        // Aralıkta en az bu kadar M5 mum olmalı

input group "=== Filtreler ==="
input double InpMaxSpreadPoints  = 40.0;      // Emir koyarken max spread (point)
input bool   InpSkipFriday       = false;     // Cuma işlem yapma
input int    InpSlippagePoints   = 30;        // Market emirlerinde max kayma (point)

CTrade   trade;
int      hATR      = INVALID_HANDLE;
datetime g_dayDone = 0;          // emirlerin konduğu / atlandığı gün
string   g_status  = "Bekleniyor";
double   g_rangeHi = 0.0, g_rangeLo = 0.0, g_buyLvl = 0.0, g_sellLvl = 0.0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpRangeStartHour >= InpRangeEndHour || InpRangeEndHour >= InpTradeEndHour || InpTradeEndHour > InpExitHour)
     { Print("[HATA] Saatler sıralı olmalı: başlangıç < aralık sonu < işlem sonu <= çıkış."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpSLATRMult <= 0 || InpTPRR <= 0 || InpATRPeriod <= 0)
     { Print("[HATA] SL çarpanı, TP oranı ve ATR periyodu > 0 olmalı."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpFixedLot <= 0 && (InpRiskPercent <= 0 || InpRiskPercent > 5))
     { Print("[HATA] Risk yüzdesi 0-5 arası olmalı."); return(INIT_PARAMETERS_INCORRECT); }

   hATR = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   if(hATR == INVALID_HANDLE)
     { PrintFormat("[HATA] ATR handle oluşturulamadı. Hata=%d", GetLastError()); return(INIT_FAILED); }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);
   trade.LogLevel(LOG_LEVEL_ERRORS);
   PrintFormat("[BİLGİ] LondonBreakoutEA başladı. %s, aralık %02d-%02d, emir %02d-%02d, çıkış %02d (sunucu saati).",
               _Symbol, InpRangeStartHour, InpRangeEndHour, InpRangeEndHour, InpTradeEndHour, InpExitHour);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hATR != INVALID_HANDLE)
      IndicatorRelease(hATR);
   Comment("");
  }

//====================================================================
//                         YARDIMCI FONKSİYONLAR
//====================================================================
datetime DayStart(const datetime t)
  {
   MqlDateTime d;
   TimeToStruct(t, d);
   d.hour = 0; d.min = 0; d.sec = 0;
   return(StructToTime(d));
  }

double NormalizePrice(const double p)
  {
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0.0) ts = _Point;
   return(NormalizeDouble(MathRound(p / ts) * ts, _Digits));
  }

bool TradeOK()
  {
   uint rc = trade.ResultRetcode();
   return(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL);
  }

void LogErr(const string what)
  {
   PrintFormat("[HATA] %s. Retcode=%u (%s) LastError=%d", what, trade.ResultRetcode(),
               trade.ResultRetcodeDescription(), GetLastError());
  }

int CountPositions()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t != 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         n++;
     }
   return(n);
  }

int CountPending()
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t != 0 && OrderGetString(ORDER_SYMBOL) == _Symbol && (ulong)OrderGetInteger(ORDER_MAGIC) == InpMagic)
         n++;
     }
   return(n);
  }

void DeletePending(const string why)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0 || OrderGetString(ORDER_SYMBOL) != _Symbol || (ulong)OrderGetInteger(ORDER_MAGIC) != InpMagic)
         continue;
      if(!trade.OrderDelete(t) || !TradeOK())
         LogErr(StringFormat("Bekleyen emir silme #%I64u", t));
      else
         PrintFormat("[BİLGİ] Bekleyen emir silindi #%I64u (%s)", t, why);
     }
  }

void ClosePositions(const string why)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      if(!trade.PositionClose(t, InpSlippagePoints) || !TradeOK())
         LogErr(StringFormat("Pozisyon kapatma #%I64u", t));
      else
         PrintFormat("[BİLGİ] Pozisyon kapatıldı #%I64u (%s)", t, why);
     }
  }

//--- Risk yüzdesine göre lot (SL mesafesi: risk)
double CalcLot(const double entry, const double risk)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   double lot;
   if(InpFixedLot > 0.0)
      lot = InpFixedLot;
   else
     {
      double loss = 0.0;
      if(!OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, 1.0, entry, entry - risk, loss) || loss == 0.0)
        {
         PrintFormat("[HATA] OrderCalcProfit başarısız. Hata=%d", GetLastError());
         return(0.0);
        }
      lot = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0 / MathAbs(loss);
     }
   lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < minLot)
     {
      PrintFormat("[UYARI] Hesaplanan lot (%.3f) min lottan küçük; risk aşılmaması için bugün işlem yok.", lot);
      return(0.0);
     }
   lot = MathMin(lot, maxLot);
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return(NormalizeDouble(lot, digits));
  }

//====================================================================
//                         GÜNLÜK KURULUM
//====================================================================
//--- Bugünün aralığını hesapla ve emirleri koy. true = gün tamamlandı (emir kondu veya atlandı)
bool SetupDay(const datetime today, const datetime now)
  {
   datetime rStart = today + InpRangeStartHour * 3600;
   datetime rEnd   = today + InpRangeEndHour * 3600;

   MqlRates rr[];
   int n = CopyRates(_Symbol, PERIOD_M5, rStart, rEnd - 1, rr);
   if(n < InpMinRangeBars)
     {
      g_status = StringFormat("Aralık verisi yetersiz (%d mum), bugün işlem yok", n);
      Print("[BİLGİ] ", g_status);
      return(true);
     }
   double hi = rr[0].high, lo = rr[0].low;
   for(int i = 1; i < n; i++)
     {
      hi = MathMax(hi, rr[i].high);
      lo = MathMin(lo, rr[i].low);
     }

   //--- ATR: aralığın son M5 mumu
   int sh = iBarShift(_Symbol, PERIOD_M5, rEnd - 300, false);
   double atr[1];
   if(sh < 0 || CopyBuffer(hATR, 0, sh, 1, atr) != 1 || atr[0] <= 0.0)
      return(false);                              // veri hazır değil, sonraki tick'te tekrar dene
   double risk = InpSLATRMult * atr[0];

   double buf = InpBufferPoints * _Point;
   double buyLvl  = NormalizePrice(hi + buf);
   double sellLvl = NormalizePrice(lo - buf);
   g_rangeHi = hi; g_rangeLo = lo; g_buyLvl = buyLvl; g_sellLvl = sellLvl;

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
      return(false);
   if((tk.ask - tk.bid) / _Point > InpMaxSpreadPoints)
     {
      g_status = StringFormat("Spread yüksek (%.0f), bekleniyor", (tk.ask - tk.bid) / _Point);
      return(false);                              // spread normale dönünce tekrar dene
     }

   //--- Aralık 10:00'dan beri zaten kırıldı mı? (EA geç başlatıldıysa)
   MqlRates since[];
   int ns = CopyRates(_Symbol, PERIOD_M5, rEnd, now, since);
   double hiS = tk.bid, loS = tk.bid;
   for(int i = 0; i < ns; i++)
     {
      hiS = MathMax(hiS, since[i].high);
      loS = MathMin(loS, since[i].low);
     }
   bool brokeUp = (hiS >= buyLvl) || (tk.ask >= buyLvl);
   bool brokeDn = (loS <= sellLvl);
   bool firstBar = (now < rEnd + 300);

   if(brokeUp && brokeDn)
     {
      g_status = "Aralık iki yönde de kırılmış, bugün işlem yok";
      Print("[BİLGİ] ", g_status);
      return(true);
     }
   if(brokeUp || brokeDn)
     {
      //--- Sadece 10:00 mumunun içindeysek araştırmadaki gibi piyasadan gir
      if(!firstBar)
        {
         g_status = "Aralık EA başlamadan kırılmış, bugün işlem yok";
         Print("[BİLGİ] ", g_status);
         return(true);
        }
      if(brokeUp && InpAllowBuy)
        {
         double entry = tk.ask;
         double lot = CalcLot(entry, risk);
         if(lot > 0.0 && (!trade.Buy(lot, _Symbol, entry, NormalizePrice(entry - risk), NormalizePrice(entry + risk * InpTPRR), "LBO_BUY") || !TradeOK()))
            LogErr("Açılışta alış");
        }
      else if(brokeDn && InpAllowSell)
        {
         double entry = tk.bid;
         double lot = CalcLot(entry, risk);
         if(lot > 0.0 && (!trade.Sell(lot, _Symbol, entry, NormalizePrice(entry + risk), NormalizePrice(entry - risk * InpTPRR), "LBO_SELL") || !TradeOK()))
            LogErr("Açılışta satış");
        }
      g_status = "Açılış mumunda kırılım, piyasadan girildi";
      return(true);
     }

   //--- Normal durum: iki tarafa stop emirleri (OCO)
   double lot = CalcLot((buyLvl + sellLvl) / 2.0, risk);
   if(lot <= 0.0)
     {
      g_status = "Lot hesaplanamadı, bugün işlem yok";
      return(true);
     }
   if(InpAllowBuy)
     {
      if(!trade.BuyStop(lot, buyLvl, _Symbol, NormalizePrice(buyLvl - risk), NormalizePrice(buyLvl + risk * InpTPRR),
                        ORDER_TIME_GTC, 0, "LBO_BUY") || !TradeOK())
         LogErr("Buy Stop");
     }
   if(InpAllowSell)
     {
      if(!trade.SellStop(lot, sellLvl, _Symbol, NormalizePrice(sellLvl + risk), NormalizePrice(sellLvl - risk * InpTPRR),
                         ORDER_TIME_GTC, 0, "LBO_SELL") || !TradeOK())
         LogErr("Sell Stop");
     }
   g_status = StringFormat("Emirler kondu: Buy %s / Sell %s, lot %.2f, SL %.2f $",
                           DoubleToString(buyLvl, _Digits), DoubleToString(sellLvl, _Digits), lot, risk);
   Print("[İŞLEM] ", g_status);
   return(true);
  }

//====================================================================
//                         ANA DÖNGÜ
//====================================================================
void OnTick()
  {
   datetime now = TimeCurrent();
   datetime today = DayStart(now);
   MqlDateTime dt;
   TimeToStruct(now, dt);

   //--- OCO: bir taraf dolduysa diğer bekleyen emri sil
   if(CountPositions() > 0 && CountPending() > 0)
      DeletePending("OCO - diğer taraf doldu");

   //--- Çıkış saati: her şeyi kapat
   if(dt.hour >= InpExitHour)
     {
      if(CountPending() > 0)   DeletePending("çıkış saati");
      if(CountPositions() > 0) ClosePositions("çıkış saati");
      g_status = "Gün bitti";
     }
   //--- İşlem penceresi bitti: dolmayan emirleri sil
   else if(dt.hour >= InpTradeEndHour)
     {
      if(CountPending() > 0)
        {
         DeletePending("işlem penceresi bitti");
         if(CountPositions() == 0) g_status = "Bugün kırılım olmadı";
        }
     }
   //--- Emir penceresi: günde bir kez kur
   else if(dt.hour >= InpRangeEndHour && g_dayDone != today)
     {
      bool skip = (InpSkipFriday && dt.day_of_week == 5) || dt.day_of_week == 0 || dt.day_of_week == 6;
      if(skip)
        {
         g_dayDone = today;
         g_status = "Bugün işlem günü değil";
        }
      else if(CountPositions() == 0 && CountPending() == 0)
        {
         if(SetupDay(today, now))
            g_dayDone = today;
        }
      else
         g_dayDone = today;                       // dünden kalan bir şey varsa yeni kurulum yapma
     }

   Comment(StringFormat("LondonBreakoutEA | %s\nAralık: %s - %s | Buy %s / Sell %s\nPozisyon: %d | Bekleyen: %d\nDurum: %s",
                        _Symbol,
                        DoubleToString(g_rangeLo, _Digits), DoubleToString(g_rangeHi, _Digits),
                        DoubleToString(g_buyLvl, _Digits), DoubleToString(g_sellLvl, _Digits),
                        CountPositions(), CountPending(), g_status));
  }
//+------------------------------------------------------------------+
