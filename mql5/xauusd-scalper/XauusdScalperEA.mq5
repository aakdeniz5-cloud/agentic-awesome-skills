//+------------------------------------------------------------------+
//|                                              XauusdScalperEA.mq5 |
//|      XAUUSD için trend filtreli EMA/RSI/ATR scalping uzman danışmanı |
//|                                                                  |
//|  KESİN KURALLAR: Martingale / grid / averaging YOK.               |
//|  Her işlem SL + TP ile birlikte gönderilir.                      |
//+------------------------------------------------------------------+
#property copyright "XauusdScalperEA"
#property version   "1.10"
#property description "XAUUSD M1/M5 scalping EA: M15 EMA50/200 trend filtresi, EMA9/21 kesişimi + RSI(7) onayı,"
#property description "ATR bazlı SL/TP, breakeven, trailing, risk yüzdesi lot, günlük limitler ve equity acil durdurma."

#include <Trade\Trade.mqh>

//--- Lot hesaplama modu
enum ENUM_LOT_MODE
  {
   LOT_RISK_PERCENT = 0, // Bakiyenin %'si kadar risk
   LOT_FIXED        = 1  // Sabit lot
  };

//--- Haber önem seviyesi filtresi
enum ENUM_NEWS_LEVEL
  {
   NEWS_ALL         = 1, // Düşük + Orta + Yüksek
   NEWS_MEDIUM_HIGH = 2, // Orta + Yüksek
   NEWS_HIGH_ONLY   = 3  // Sadece yüksek önemli
  };

//--- Haber olayı (sunucu saatiyle)
struct NewsEvent
  {
   datetime          time;
   string            currency;
   int               importance;
   string            title;
   bool              fromCsv;
  };

//====================================================================
//                         INPUT PARAMETRELERİ
//====================================================================
input group "=== Genel ==="
input ulong            InpMagic                 = 20261008;      // Magic number
input string           InpComment               = "XAU_Scalper"; // İşlem yorumu
input int              InpMaxPositions          = 1;             // Aynı anda max pozisyon (bu sembol + magic)
input double           InpPipSizeOverride       = 0.0;           // Pip büyüklüğü (0 = otomatik)

input group "=== Zaman Dilimleri ==="
input ENUM_TIMEFRAMES  InpEntryTF               = PERIOD_M5;     // Giriş zaman dilimi (M1/M5)
input ENUM_TIMEFRAMES  InpTrendTF               = PERIOD_M15;    // Trend zaman dilimi

input group "=== Trend Filtresi (Trend TF) ==="
input int              InpTrendFastEMA          = 50;            // Trend hızlı EMA
input int              InpTrendSlowEMA          = 200;           // Trend yavaş EMA
input bool             InpRequirePriceVsSlowEMA = true;          // Fiyat da yavaş EMA'nın doğru tarafında olsun

input group "=== Giriş Sinyali (Giriş TF) ==="
input int              InpFastEMA               = 9;             // Hızlı EMA
input int              InpSlowEMA               = 21;            // Yavaş EMA
input ENUM_APPLIED_PRICE InpAppliedPrice        = PRICE_CLOSE;   // Uygulanan fiyat
input int              InpRSIPeriod             = 7;             // RSI periyodu
input double           InpRSIBuyMin             = 50.0;          // Alış: RSI bu değerin ÜSTÜNDE
input double           InpRSIBuyMax             = 75.0;          // Alış: RSI bu değerin ALTINDA
input double           InpRSISellMax            = 50.0;          // Satış: RSI bu değerin ALTINDA
input double           InpRSISellMin            = 25.0;          // Satış: RSI bu değerin ÜSTÜNDE

input group "=== Volatilite Filtresi ==="
input int              InpATRPeriod             = 14;            // ATR periyodu (giriş TF)
input double           InpMinATRPips            = 80.0;          // Min ATR (pip) - altında işlem yok
input double           InpMaxATRPips            = 0.0;           // Max ATR (pip) - üstünde işlem yok (0 = kapalı)

input group "=== Stop Loss / Take Profit ==="
input double           InpSLATRMult             = 1.5;           // SL = ATR x çarpan
input double           InpRiskReward            = 1.5;           // TP = SL x Risk/Ödül
input double           InpMinSLPips             = 50.0;          // Minimum SL mesafesi (pip)
input double           InpMaxSLPips             = 0.0;           // Maksimum SL (pip) - aşarsa işlem yok (0 = kapalı)

input group "=== Breakeven ==="
input bool             InpUseBreakeven          = true;          // Breakeven aktif
input double           InpBETriggerPct          = 50.0;          // TP mesafesinin %'si kadar kârda SL girişe
input double           InpBELockPips            = 2.0;           // Girişin ötesine kilitlenecek pip (maliyet karşılığı)

input group "=== Trailing Stop (ATR) ==="
input bool             InpUseTrailing           = true;          // Trailing aktif
input double           InpTrailATRMult          = 1.0;           // Trailing mesafesi = ATR x çarpan
input double           InpTrailStepPips         = 5.0;           // Minimum SL güncelleme adımı (pip)
input bool             InpTrailAfterBEOnly      = true;          // Sadece breakeven sonrası trail et

input group "=== Lot Yönetimi ==="
input ENUM_LOT_MODE    InpLotMode               = LOT_RISK_PERCENT; // Lot modu
input double           InpRiskPercent           = 0.5;           // İşlem başı risk (% bakiye)
input double           InpFixedLot              = 0.01;          // Sabit lot
input bool             InpSkipIfMinLotTooRisky  = true;          // Min lot riski aşıyorsa işlemi atla

input group "=== Günlük Limitler ==="
input double           InpMaxDailyLossPct       = 2.0;           // Günlük max zarar (% gün başı bakiye, 0 = kapalı)
input bool             InpCloseOnDailyLoss      = true;          // Limit aşılınca açık pozisyonları kapat
input int              InpMaxTradesPerDay       = 10;            // Günlük max işlem sayısı (0 = sınırsız)
input int              InpMaxConsecLosses       = 3;             // Art arda max zarar (0 = sınırsız)

input group "=== Equity Acil Durdurma ==="
input bool             InpUseEquityStop         = true;          // Equity acil durdurma aktif
input double           InpMaxEquityDDPct        = 10.0;          // Zirve equity'den max düşüş (%)
input bool             InpResetEmergency        = false;         // Acil durum kilidini sıfırla (true yapıp yeniden yükle)

input group "=== Piyasa Filtreleri ==="
input double           InpMaxSpreadPips         = 35.0;          // Max spread (pip)
input int              InpMaxSlippagePoints     = 30;            // Max slippage / deviation (point)
input int              InpBrokerGMTOffset       = 2;             // Broker sunucu saati GMT farkı (kış saati, saat)
input bool             InpAutoUSDST             = true;          // ABD yaz saatinde farka otomatik +1 ekle
input bool             InpUseLondon             = true;          // Londra seansı
input int              InpLondonStartGMT        = 7;             // Londra başlangıç (GMT saat)
input int              InpLondonEndGMT          = 16;            // Londra bitiş (GMT saat)
input bool             InpUseNewYork            = true;          // New York seansı
input int              InpNYStartGMT            = 12;            // New York başlangıç (GMT saat)
input int              InpNYEndGMT              = 21;            // New York bitiş (GMT saat)
input bool             InpFridayFilter          = true;          // Cuma akşamı yeni işlem açma
input int              InpFridayStopHourGMT     = 19;            // Cuma bu saatten sonra yeni işlem yok (GMT)
input bool             InpCloseBeforeWeekend    = false;         // Hafta sonu öncesi açık pozisyonları kapat
input int              InpFridayCloseHourGMT    = 20;            // Cuma kapanış saati (GMT)

input group "=== Haber Filtresi ==="
input bool             InpUseNewsFilter         = true;          // Haber filtresi aktif
input ENUM_NEWS_LEVEL  InpNewsMinImportance     = NEWS_HIGH_ONLY; // Dikkate alınacak min haber önemi
input string           InpNewsCurrencies        = "USD";         // Para birimleri (virgülle, örn. USD,EUR)
input int              InpNewsMinutesBefore     = 30;            // Haberden kaç dk ÖNCE yeni işlem yok
input int              InpNewsMinutesAfter      = 30;            // Haberden kaç dk SONRA yeni işlem yok
input bool             InpNewsClosePositions    = false;         // Haber öncesi açık pozisyonları kapat
input int              InpNewsCloseMinutesBefore = 5;            // Habere kaç dk kala kapatılsın
input bool             InpNewsUseCalendar       = true;          // Canlıda MT5 ekonomik takvimini kullan
input string           InpNewsCsvFile           = "xau_news.csv"; // Haber CSV dosyası (tester için, boş = yok)
input bool             InpNewsCsvCommonFolder   = true;          // CSV ortak klasörde (Terminal\Common\Files)
input bool             InpNewsCsvTimeIsGMT      = false;         // CSV saatleri GMT (false = sunucu saati)

input group "=== Panel ==="
input bool             InpShowPanel             = true;          // Grafikte bilgi paneli göster
input int              InpPanelX                = 10;            // Panel X konumu
input int              InpPanelY                = 25;            // Panel Y konumu

//====================================================================
//                         GLOBAL DEĞİŞKENLER
//====================================================================
CTrade   trade;

int      hFastEMA   = INVALID_HANDLE;
int      hSlowEMA   = INVALID_HANDLE;
int      hTrendFast = INVALID_HANDLE;
int      hTrendSlow = INVALID_HANDLE;
int      hRSI       = INVALID_HANDLE;
int      hATR       = INVALID_HANDLE;

double   g_point    = 0.0;
double   g_pip      = 0.0;
int      g_digits   = 0;

datetime g_lastBarTime     = 0;
datetime g_currentDay      = 0;
double   g_dayStartBalance = 0.0;
bool     g_dayHalted       = false;
string   g_haltReason      = "";

bool     g_emergency       = false;
double   g_peakEquity      = 0.0;
string   g_gvPeak          = "";
string   g_gvEmergency     = "";

int      g_tradesToday     = 0;
int      g_consecLosses    = 0;
double   g_realizedToday   = 0.0;
bool     g_statsDirty      = true;

string   g_lastReason      = "";
uint     g_lastPanelTick   = 0;
bool     g_panelEnabled    = false;

NewsEvent g_news[];                 // zamana göre sıralı haber listesi (CSV + takvim)
int      g_newsStart       = 0;     // geçmiş olayları atlamak için başlangıç indeksi
string   g_newsCurrencies[];
datetime g_lastCalendarUpdate = 0;

#define PANEL_PREFIX "XSCALP_"
#define PANEL_LINES  11

//====================================================================
//                         OnInit / OnDeinit
//====================================================================
int OnInit()
  {
//--- Parametre kontrolleri
   if(InpFastEMA <= 0 || InpSlowEMA <= 0 || InpFastEMA >= InpSlowEMA)
     { Print("[HATA] Hızlı EMA, yavaş EMA'dan küçük ve > 0 olmalı."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpTrendFastEMA <= 0 || InpTrendSlowEMA <= 0 || InpTrendFastEMA >= InpTrendSlowEMA)
     { Print("[HATA] Trend hızlı EMA, trend yavaş EMA'dan küçük ve > 0 olmalı."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpSLATRMult <= 0 || InpRiskReward <= 0 || InpATRPeriod <= 0 || InpRSIPeriod <= 0)
     { Print("[HATA] SL çarpanı, R/Ö, ATR ve RSI periyotları > 0 olmalı."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpLotMode == LOT_RISK_PERCENT && (InpRiskPercent <= 0 || InpRiskPercent > 5))
     { Print("[HATA] Risk yüzdesi 0 ile 5 arasında olmalı."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpLotMode == LOT_FIXED && InpFixedLot <= 0)
     { Print("[HATA] Sabit lot > 0 olmalı."); return(INIT_PARAMETERS_INCORRECT); }
   if(InpMaxPositions < 1)
     { Print("[HATA] Max pozisyon en az 1 olmalı."); return(INIT_PARAMETERS_INCORRECT); }

//--- Sembol bilgileri (4/5 hane ve 2/3 hane uyumlu pip hesabı)
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(InpPipSizeOverride > 0.0)
      g_pip = InpPipSizeOverride;
   else
      g_pip = (g_digits == 3 || g_digits == 5) ? g_point * 10.0 : g_point;

//--- CTrade ayarları
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpMaxSlippagePoints);
   trade.SetMarginMode();
   if(!trade.SetTypeFillingBySymbol(_Symbol))
      PrintFormat("[UYARI] Dolum modu sembolden alınamadı, varsayılan kullanılacak. Hata=%d", GetLastError());
   trade.LogLevel(LOG_LEVEL_ERRORS);

//--- İndikatör handle'ları (sadece burada oluşturulur)
   hFastEMA   = iMA(_Symbol, InpEntryTF, InpFastEMA, 0, MODE_EMA, InpAppliedPrice);
   hSlowEMA   = iMA(_Symbol, InpEntryTF, InpSlowEMA, 0, MODE_EMA, InpAppliedPrice);
   hTrendFast = iMA(_Symbol, InpTrendTF, InpTrendFastEMA, 0, MODE_EMA, InpAppliedPrice);
   hTrendSlow = iMA(_Symbol, InpTrendTF, InpTrendSlowEMA, 0, MODE_EMA, InpAppliedPrice);
   hRSI       = iRSI(_Symbol, InpEntryTF, InpRSIPeriod, InpAppliedPrice);
   hATR       = iATR(_Symbol, InpEntryTF, InpATRPeriod);

   if(hFastEMA == INVALID_HANDLE || hSlowEMA == INVALID_HANDLE || hTrendFast == INVALID_HANDLE ||
      hTrendSlow == INVALID_HANDLE || hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      PrintFormat("[HATA] İndikatör handle oluşturulamadı. Hata=%d", GetLastError());
      return(INIT_FAILED);
     }

//--- Acil durum durumunu kalıcı tutmak için global değişkenler
   g_gvPeak      = PANEL_PREFIX + _Symbol + "_" + (string)InpMagic + "_PEAK";
   g_gvEmergency = PANEL_PREFIX + _Symbol + "_" + (string)InpMagic + "_EMERG";

   if(MQLInfoInteger(MQL_TESTER) || InpResetEmergency)
     {
      GlobalVariableDel(g_gvPeak);
      GlobalVariableDel(g_gvEmergency);
     }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = GlobalVariableCheck(g_gvPeak) ? GlobalVariableGet(g_gvPeak) : equity;
   if(g_peakEquity < equity)
      g_peakEquity = equity;
   GlobalVariableSet(g_gvPeak, g_peakEquity);
   g_emergency = (GlobalVariableCheck(g_gvEmergency) && GlobalVariableGet(g_gvEmergency) > 0.5);
   if(g_emergency)
      Print("[UYARI] Önceki acil durdurma kilidi aktif. Sıfırlamak için InpResetEmergency=true ile yeniden yükleyin.");

//--- Günlük istatistikleri hazırla
   g_currentDay = 0;
   CheckNewDay();

//--- Haber filtresi
   if(InpUseNewsFilter)
      InitNews();

//--- İlk mumda işlem açmamak için mevcut mum zamanını kaydet
   g_lastBarTime = iTime(_Symbol, InpEntryTF, 0);

//--- Panel (optimizasyon / görsel olmayan testte kapalı)
   g_panelEnabled = InpShowPanel && (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
   if(g_panelEnabled)
     {
      CreatePanel();
      if(!MQLInfoInteger(MQL_TESTER))
         EventSetTimer(1);
      UpdatePanel(true);
     }

   PrintFormat("[BİLGİ] EA başlatıldı. Sembol=%s Digits=%d Point=%s Pip=%s Magic=%I64u",
               _Symbol, g_digits, DoubleToString(g_point, g_digits), DoubleToString(g_pip, g_digits), InpMagic);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
//--- Handle'ları serbest bırak
   if(hFastEMA   != INVALID_HANDLE) IndicatorRelease(hFastEMA);
   if(hSlowEMA   != INVALID_HANDLE) IndicatorRelease(hSlowEMA);
   if(hTrendFast != INVALID_HANDLE) IndicatorRelease(hTrendFast);
   if(hTrendSlow != INVALID_HANDLE) IndicatorRelease(hTrendSlow);
   if(hRSI       != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hATR       != INVALID_HANDLE) IndicatorRelease(hATR);
//--- Paneli temizle
   ObjectsDeleteAll(0, PANEL_PREFIX);
   ChartRedraw();
  }

//====================================================================
//                         ANA OLAY FONKSİYONLARI
//====================================================================
void OnTick()
  {
   CheckNewDay();

//--- İşlem geçmişi değiştiyse günlük istatistikleri yenile
   if(g_statsDirty)
     {
      RefreshDailyStats();
      g_statsDirty = false;
     }

//--- 1) Equity bazlı acil durdurma (en yüksek öncelik)
   CheckEquityStop();
   if(g_emergency)
     {
      UpdatePanel(false);
      return;
     }

//--- 2) Günlük zarar limiti
   CheckDailyLoss();

//--- 3) Hafta sonu öncesi kapatma (opsiyonel)
   CheckWeekendClose();

//--- 4) Haber takvimini güncelle, gerekirse haber öncesi kapat
   UpdateCalendarNews(false);
   CheckNewsClose();

//--- 5) Açık pozisyon yönetimi (breakeven / trailing) - her tick
   ManagePositions();

//--- 6) Yeni sinyal kontrolü - SADECE yeni mum açılışında
   if(IsNewBar())
     {
      RefreshDailyStats();
      string reason = "";
      if(CanOpenNewTrade(reason))
         CheckEntrySignal();
      else if(reason != g_lastReason)
         PrintFormat("[BİLGİ] Yeni işlem açılmıyor: %s", reason);
      g_lastReason = reason;
     }

   UpdatePanel(false);
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateCalendarNews(false);
   UpdatePanel(true);
  }

//+------------------------------------------------------------------+
//| Yeni deal eklendiğinde istatistikleri tazelemek için işaretle    |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
      g_statsDirty = true;
  }

//====================================================================
//                         YARDIMCI FONKSİYONLAR
//====================================================================
//--- İndikatör tamponundan tek değer oku
bool GetValue(const int handle, const int buffer, const int shift, double &value, const bool quiet = false)
  {
   double arr[1];
   ResetLastError();
   if(CopyBuffer(handle, buffer, shift, 1, arr) != 1)
     {
      if(!quiet)
         PrintFormat("[HATA] CopyBuffer başarısız. handle=%d shift=%d hata=%d", handle, shift, GetLastError());
      return(false);
     }
   value = arr[0];
   return(true);
  }

//--- Fiyatı tick size'a göre normalize et
double NormalizePrice(const double price)
  {
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = g_point;
   return(NormalizeDouble(MathRound(price / tickSize) * tickSize, g_digits));
  }

//--- Lot adımının ondalık basamak sayısı
int VolumeDigits(const double step)
  {
   int d = 0;
   while(d < 8 && MathAbs(step * MathPow(10, d) - MathRound(step * MathPow(10, d))) > 1e-8)
      d++;
   return(d);
  }

//--- Lotu broker kurallarına göre aşağı yuvarla
double NormalizeLot(const double lot)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      step = 0.01;
   double v = MathFloor(lot / step + 1e-9) * step;
   return(NormalizeDouble(v, VolumeDigits(step)));
  }

//--- Son işlem sonucunun başarılı olup olmadığı
bool TradeSucceeded()
  {
   uint rc = trade.ResultRetcode();
   return(rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED || rc == TRADE_RETCODE_DONE_PARTIAL);
  }

//--- Hata loglama
void LogTradeError(const string action)
  {
   PrintFormat("[HATA] %s başarısız. Retcode=%u (%s) LastError=%d",
               action, trade.ResultRetcode(), trade.ResultRetcodeDescription(), GetLastError());
  }

//--- Yeni mum kontrolü (giriş zaman dilimi)
bool IsNewBar()
  {
   datetime t = iTime(_Symbol, InpEntryTF, 0);
   if(t == 0)
      return(false);
   if(t != g_lastBarTime)
     {
      bool first = (g_lastBarTime == 0);
      g_lastBarTime = t;
      return(!first);
     }
   return(false);
  }

//--- Sunucu zamanından GMT zaman yapısı
//--- Ayın n'inci Pazar günü (00:00)
datetime NthSunday(const int year, const int month, const int n)
  {
   MqlDateTime d;
   ZeroMemory(d);
   d.year = year;
   d.mon  = month;
   d.day  = 1;
   datetime first = StructToTime(d);
   TimeToStruct(first, d);
   int add = (7 - d.day_of_week) % 7;
   return(first + (datetime)((add + 7 * (n - 1)) * 86400));
  }

//--- Verilen GMT zamanı ABD yaz saati döneminde mi? (Mart 2. Pazar - Kasım 1. Pazar)
bool IsUSDST(const datetime gmt)
  {
   MqlDateTime dt;
   TimeToStruct(gmt, dt);
   datetime start = NthSunday(dt.year, 3, 2) + 7 * 3600;   // 02:00 New York = 07:00 GMT
   datetime end   = NthSunday(dt.year, 11, 1) + 6 * 3600;  // 02:00 New York = 06:00 GMT
   return(gmt >= start && gmt < end);
  }

//--- Broker GMT farkı (saniye), yaz saati dahil
int BrokerOffsetSeconds(const datetime gmt)
  {
   int off = InpBrokerGMTOffset;
   if(InpAutoUSDST && IsUSDST(gmt))
      off += 1;
   return(off * 3600);
  }

//--- Sunucu zamanından GMT zamanı
datetime ServerToGmt(const datetime server)
  {
   datetime approx = server - (datetime)(InpBrokerGMTOffset * 3600);
   return(server - (datetime)BrokerOffsetSeconds(approx));
  }

//--- Sunucu zamanından GMT zaman yapısı
void GmtTime(MqlDateTime &dt)
  {
   TimeToStruct(ServerToGmt(TimeCurrent()), dt);
  }

//--- Saat penceresi kontrolü (gece yarısını aşan pencereler desteklenir)
bool InWindow(const int hour, const int start, const int end)
  {
   if(start == end)
      return(false);
   if(start < end)
      return(hour >= start && hour < end);
   return(hour >= start || hour < end);
  }

//--- Seans filtresi
bool IsTradingSession()
  {
   if(!InpUseLondon && !InpUseNewYork)
      return(true);
   MqlDateTime dt;
   GmtTime(dt);
   bool london = InpUseLondon  && InWindow(dt.hour, InpLondonStartGMT, InpLondonEndGMT);
   bool ny     = InpUseNewYork && InWindow(dt.hour, InpNYStartGMT, InpNYEndGMT);
   return(london || ny);
  }

//--- Cuma akşamı / hafta sonu filtresi
bool IsWeekendBlocked()
  {
   MqlDateTime dt;
   GmtTime(dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return(true);
   if(InpFridayFilter && dt.day_of_week == 5 && dt.hour >= InpFridayStopHourGMT)
      return(true);
   return(false);
  }

//--- Mevcut spread (pip)
double SpreadPips()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || g_pip <= 0.0)
      return(0.0);
   return((ask - bid) / g_pip);
  }

//--- Bu EA'ya ait pozisyon sayısı
int CountPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         count++;
     }
   return(count);
  }

//--- Bu EA'ya ait açık pozisyonların yüzen kâr/zararı
double FloatingPL()
  {
   double pl = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         pl += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return(pl);
  }

//--- Bu EA'ya ait tüm pozisyonları kapat
void CloseAllPositions(const string why)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      ResetLastError();
      if(!trade.PositionClose(ticket, InpMaxSlippagePoints) || !TradeSucceeded())
         LogTradeError(StringFormat("Pozisyon kapatma #%I64u (%s)", ticket, why));
      else
         PrintFormat("[BİLGİ] Pozisyon kapatıldı #%I64u. Sebep: %s", ticket, why);
     }
   g_statsDirty = true;
  }

//====================================================================
//                     GÜNLÜK İSTATİSTİK VE LİMİTLER
//====================================================================
//--- Gün değişimini kontrol et (sunucu saatine göre)
void CheckNewDay()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   datetime today = StructToTime(dt);
   if(today == g_currentDay)
      return;

   g_currentDay = today;
   g_dayHalted  = false;
   g_haltReason = "";
   RefreshDailyStats();
   g_statsDirty = false;
//--- Gün başı bakiye: mevcut bakiye - bugün gerçekleşen kâr/zarar
   g_dayStartBalance = AccountInfoDouble(ACCOUNT_BALANCE) - g_realizedToday;
   PrintFormat("[BİLGİ] Yeni gün: %s  Gün başı bakiye=%.2f", TimeToString(today, TIME_DATE), g_dayStartBalance);
  }

//--- Bugünkü işlem sayısı, gerçekleşen K/Z ve art arda zarar sayısı
void RefreshDailyStats()
  {
   if(!HistorySelect(g_currentDay, TimeCurrent() + 86400))
     {
      PrintFormat("[HATA] HistorySelect başarısız. Hata=%d", GetLastError());
      return;
     }
   int    trades   = 0;
   int    consec   = 0;
   double realized = 0.0;
   int    total    = HistoryDealsTotal();

   for(int i = 0; i < total; i++)   // kronolojik sıra
     {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)
         continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      double pl = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                  HistoryDealGetDouble(ticket, DEAL_SWAP) +
                  HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      if(entry == DEAL_ENTRY_IN)
        {
         trades++;
         realized += pl;          // giriş komisyonu
        }
      else if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY)
        {
         realized += pl;
         if(pl < 0.0)
            consec++;
         else if(pl > 0.0)
            consec = 0;
        }
     }
   g_tradesToday   = trades;
   g_consecLosses  = consec;
   g_realizedToday = realized;
  }

//--- Günlük zarar limiti kontrolü
void CheckDailyLoss()
  {
   if(g_dayHalted)
     {
      if(InpCloseOnDailyLoss && CountPositions() > 0)
         CloseAllPositions("Günlük zarar limiti");
      return;
     }
   if(InpMaxDailyLossPct <= 0.0 || g_dayStartBalance <= 0.0)
      return;

   double dayPL = g_realizedToday + FloatingPL();
   double limit = -g_dayStartBalance * InpMaxDailyLossPct / 100.0;
   if(dayPL <= limit)
     {
      g_dayHalted  = true;
      g_haltReason = StringFormat("Günlük zarar limiti (%.2f <= %.2f)", dayPL, limit);
      PrintFormat("[UYARI] %s. Bugün yeni işlem açılmayacak.", g_haltReason);
      if(InpCloseOnDailyLoss)
         CloseAllPositions("Günlük zarar limiti");
     }
  }

//--- Equity bazlı acil durdurma
void CheckEquityStop()
  {
   if(!InpUseEquityStop)
      return;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_peakEquity)
     {
      g_peakEquity = equity;
      GlobalVariableSet(g_gvPeak, g_peakEquity);
     }
   if(g_emergency)
     {
      if(CountPositions() > 0)
         CloseAllPositions("Acil durdurma");
      return;
     }
   if(g_peakEquity <= 0.0)
      return;
   double dd = (g_peakEquity - equity) / g_peakEquity * 100.0;
   if(dd >= InpMaxEquityDDPct)
     {
      g_emergency = true;
      GlobalVariableSet(g_gvEmergency, 1.0);
      PrintFormat("[ACİL] Equity drawdown %.2f%% >= %.2f%%. Tüm pozisyonlar kapatılıyor, EA işlemi durdurdu.",
                  dd, InpMaxEquityDDPct);
      CloseAllPositions("Acil durdurma");
     }
  }

//--- Cuma kapanış öncesi pozisyonları kapat (opsiyonel)
void CheckWeekendClose()
  {
   if(!InpCloseBeforeWeekend)
      return;
   MqlDateTime dt;
   GmtTime(dt);
   if(dt.day_of_week == 5 && dt.hour >= InpFridayCloseHourGMT && CountPositions() > 0)
      CloseAllPositions("Hafta sonu öncesi kapanış");
  }

//--- Yeni işlem açılabilir mi? (yan etkisiz, panel de kullanır)
bool CanOpenNewTrade(string &reason)
  {
   if(g_emergency)
     { reason = "ACİL DURDURMA aktif"; return(false); }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
     { reason = "Otomatik işlem izni kapalı"; return(false); }
   if(SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
     { reason = "Sembolde tam işlem izni yok"; return(false); }
   if(g_dayHalted)
     { reason = g_haltReason; return(false); }
   if(InpMaxTradesPerDay > 0 && g_tradesToday >= InpMaxTradesPerDay)
     { reason = "Günlük işlem limiti doldu"; return(false); }
   if(InpMaxConsecLosses > 0 && g_consecLosses >= InpMaxConsecLosses)
     { reason = "Art arda zarar limiti doldu"; return(false); }
   if(CountPositions() >= InpMaxPositions)
     { reason = "Pozisyon açık"; return(false); }
   if(IsWeekendBlocked())
     { reason = "Cuma akşamı / hafta sonu"; return(false); }
   if(!IsTradingSession())
     { reason = "Seans dışı"; return(false); }
   string newsReason = "";
   if(IsNewsBlocked(newsReason))
     { reason = newsReason; return(false); }
   double spr = SpreadPips();
   if(InpMaxSpreadPips > 0.0 && spr > InpMaxSpreadPips)
     { reason = StringFormat("Spread yüksek (%.1f pip)", spr); return(false); }
   reason = "Sinyal bekleniyor";
   return(true);
  }

//====================================================================
//                         GİRİŞ SİNYALİ
//====================================================================
void CheckEntrySignal()
  {
   double f1 = 0, f2 = 0, s1 = 0, s2 = 0, tFast = 0, tSlow = 0, rsi = 0, atr = 0;
//--- Kapanmış mumlar kullanılır (shift 1 ve 2) - repaint yok
   if(!GetValue(hFastEMA, 0, 1, f1) || !GetValue(hFastEMA, 0, 2, f2) ||
      !GetValue(hSlowEMA, 0, 1, s1) || !GetValue(hSlowEMA, 0, 2, s2) ||
      !GetValue(hTrendFast, 0, 1, tFast) || !GetValue(hTrendSlow, 0, 1, tSlow) ||
      !GetValue(hRSI, 0, 1, rsi) || !GetValue(hATR, 0, 1, atr))
      return;

//--- Volatilite filtresi
   double atrPips = atr / g_pip;
   if(atrPips < InpMinATRPips)
     {
      PrintFormat("[BİLGİ] ATR düşük (%.1f pip < %.1f). Sinyal kontrolü atlandı.", atrPips, InpMinATRPips);
      return;
     }
   if(InpMaxATRPips > 0.0 && atrPips > InpMaxATRPips)
     {
      PrintFormat("[BİLGİ] ATR aşırı yüksek (%.1f pip > %.1f). Sinyal kontrolü atlandı.", atrPips, InpMaxATRPips);
      return;
     }

//--- Trend filtresi (trend TF son kapanmış mum)
   double trendClose = iClose(_Symbol, InpTrendTF, 1);
   bool trendUp   = (tFast > tSlow) && (!InpRequirePriceVsSlowEMA || trendClose > tSlow);
   bool trendDown = (tFast < tSlow) && (!InpRequirePriceVsSlowEMA || trendClose < tSlow);

//--- EMA kesişimi
   bool crossUp   = (f2 <= s2 && f1 > s1);
   bool crossDown = (f2 >= s2 && f1 < s1);

//--- RSI onayı
   bool rsiBuy  = (rsi > InpRSIBuyMin  && rsi < InpRSIBuyMax);
   bool rsiSell = (rsi < InpRSISellMax && rsi > InpRSISellMin);

   if(crossUp && trendUp && rsiBuy)
      OpenTrade(ORDER_TYPE_BUY, atr);
   else if(crossDown && trendDown && rsiSell)
      OpenTrade(ORDER_TYPE_SELL, atr);
  }

//====================================================================
//                         LOT HESABI
//====================================================================
double CalcLot(const ENUM_ORDER_TYPE type, const double price, const double sl)
  {
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot    = 0.0;

   if(InpLotMode == LOT_FIXED)
      lot = InpFixedLot;
   else
     {
      double riskMoney  = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      double lossPerLot = 0.0;
      //--- 1 lot için SL'de oluşacak zarar (hesap para biriminde)
      if(!OrderCalcProfit(type, _Symbol, 1.0, price, sl, lossPerLot))
        {
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         if(tickValue <= 0.0 || tickSize <= 0.0)
           {
            PrintFormat("[HATA] Tick değeri alınamadı. Hata=%d", GetLastError());
            return(0.0);
           }
         lossPerLot = MathAbs(price - sl) / tickSize * tickValue;
        }
      lossPerLot = MathAbs(lossPerLot);
      if(lossPerLot <= 0.0)
        {
         Print("[HATA] Lot başı zarar hesaplanamadı.");
         return(0.0);
        }
      lot = riskMoney / lossPerLot;
     }

   lot = NormalizeLot(lot);
   if(lot < minLot)
     {
      if(InpLotMode == LOT_RISK_PERCENT && InpSkipIfMinLotTooRisky)
        {
         PrintFormat("[UYARI] Hesaplanan lot (%.4f) min lottan (%.2f) küçük. Risk aşılmaması için işlem atlandı.", lot, minLot);
         return(0.0);
        }
      lot = minLot;
     }
   if(lot > maxLot)
      lot = maxLot;

//--- Teminat kontrolü: serbest teminatın %90'ını aşma
   double margin = 0.0;
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(OrderCalcMargin(type, _Symbol, lot, price, margin) && margin > freeMargin * 0.9)
     {
      if(margin <= 0.0)
         return(0.0);
      lot = NormalizeLot(lot * freeMargin * 0.9 / margin);
      if(lot < minLot)
        {
         PrintFormat("[UYARI] Yetersiz teminat. Gerekli=%.2f Serbest=%.2f", margin, freeMargin);
         return(0.0);
        }
     }
   return(lot);
  }

//====================================================================
//                         İŞLEM AÇMA
//====================================================================
void OpenTrade(const ENUM_ORDER_TYPE type, const double atr)
  {
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
     {
      PrintFormat("[HATA] Tick alınamadı. Hata=%d", GetLastError());
      return;
     }
   double price = (type == ORDER_TYPE_BUY) ? tick.ask : tick.bid;

//--- SL mesafesi: ATR x çarpan, minimum SL ile sınırlı
   double slDist = atr * InpSLATRMult;
   if(slDist < InpMinSLPips * g_pip)
      slDist = InpMinSLPips * g_pip;

//--- Broker StopLevel / FreezeLevel kontrolü (spread dahil, çünkü kontrol karşı fiyattan yapılır)
   double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   double freeze    = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * g_point;
   double spread    = tick.ask - tick.bid;
   double brokerMin = MathMax(stopLevel, freeze) + spread + 2.0 * g_point;
   if(slDist < brokerMin)
      slDist = brokerMin;

   if(InpMaxSLPips > 0.0 && slDist > InpMaxSLPips * g_pip)
     {
      PrintFormat("[BİLGİ] SL mesafesi (%.1f pip) maksimumu (%.1f) aşıyor. İşlem atlandı.", slDist / g_pip, InpMaxSLPips);
      return;
     }

   double tpDist = slDist * InpRiskReward;
   if(tpDist < brokerMin)
      tpDist = brokerMin;

   double sl, tp;
   if(type == ORDER_TYPE_BUY)
     {
      sl = NormalizePrice(price - slDist);
      tp = NormalizePrice(price + tpDist);
     }
   else
     {
      sl = NormalizePrice(price + slDist);
      tp = NormalizePrice(price - tpDist);
     }

   double lot = CalcLot(type, price, sl);
   if(lot <= 0.0)
      return;

//--- SL ve TP emirle BİRLİKTE gönderilir
   ResetLastError();
   bool sent = (type == ORDER_TYPE_BUY) ? trade.Buy(lot, _Symbol, price, sl, tp, InpComment)
                                        : trade.Sell(lot, _Symbol, price, sl, tp, InpComment);
   string side = (type == ORDER_TYPE_BUY) ? "ALIŞ" : "SATIŞ";
   if(!sent || !TradeSucceeded())
     {
      LogTradeError(StringFormat("%s emri (lot=%.2f fiyat=%s SL=%s TP=%s)", side, lot,
                                 DoubleToString(price, g_digits), DoubleToString(sl, g_digits), DoubleToString(tp, g_digits)));
      return;
     }
   PrintFormat("[İŞLEM] %s açıldı. Lot=%.2f Fiyat=%s SL=%s TP=%s ATR=%.1f pip Spread=%.1f pip",
               side, lot, DoubleToString(trade.ResultPrice(), g_digits), DoubleToString(sl, g_digits),
               DoubleToString(tp, g_digits), atr / g_pip, spread / g_pip);
   g_statsDirty = true;
  }

//====================================================================
//                    POZİSYON YÖNETİMİ (BE / TRAILING)
//====================================================================
void ManagePositions()
  {
   if(!InpUseBreakeven && !InpUseTrailing)
      return;
   if(CountPositions() == 0)
      return;

   double atr = 0.0;
   bool haveATR = GetValue(hATR, 0, 1, atr, true);
   double bid       = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask       = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * g_point;
   double freeze    = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * g_point;
   double step      = InpTrailStepPips * g_pip;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      long   type  = PositionGetInteger(POSITION_TYPE);
      double open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double newSL = sl;

      if(type == POSITION_TYPE_BUY)
        {
         double profitDist = bid - open;
         double tpDist     = (tp > 0.0) ? tp - open : 0.0;
         bool   beDone     = (sl > 0.0 && sl >= open);

         //--- Breakeven: TP mesafesinin X%'ine ulaşınca SL girişe (+kilit)
         if(InpUseBreakeven && !beDone && tpDist > 0.0 && profitDist >= tpDist * InpBETriggerPct / 100.0)
           {
            double be = open + InpBELockPips * g_pip;
            if(sl == 0.0 || be > newSL)
               newSL = be;
           }
         //--- ATR trailing
         if(InpUseTrailing && haveATR && atr > 0.0 && (!InpTrailAfterBEOnly || (newSL > 0.0 && newSL >= open)))
           {
            double tr = bid - atr * InpTrailATRMult;
            if(newSL == 0.0 || tr > newSL + step)
               newSL = tr;
           }

         newSL = NormalizePrice(newSL);
         if(newSL <= sl + g_point * 0.5 && sl > 0.0)
            continue;                                   // iyileşme yok
         if(bid - newSL < stopLevel + g_point)
            continue;                                   // StopLevel ihlali, sonraki tick
         if(sl > 0.0 && bid - sl <= freeze)
            continue;                                   // FreezeLevel: değişiklik yasak
         if(tp > 0.0 && tp - bid <= freeze)
            continue;
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double profitDist = open - ask;
         double tpDist     = (tp > 0.0) ? open - tp : 0.0;
         bool   beDone     = (sl > 0.0 && sl <= open);

         if(InpUseBreakeven && !beDone && tpDist > 0.0 && profitDist >= tpDist * InpBETriggerPct / 100.0)
           {
            double be = open - InpBELockPips * g_pip;
            if(sl == 0.0 || be < newSL)
               newSL = be;
           }
         if(InpUseTrailing && haveATR && atr > 0.0 && (!InpTrailAfterBEOnly || (newSL > 0.0 && newSL <= open)))
           {
            double tr = ask + atr * InpTrailATRMult;
            if(newSL == 0.0 || tr < newSL - step)
               newSL = tr;
           }

         newSL = NormalizePrice(newSL);
         if(sl > 0.0 && newSL >= sl - g_point * 0.5)
            continue;
         if(newSL - ask < stopLevel + g_point)
            continue;
         if(sl > 0.0 && sl - ask <= freeze)
            continue;
         if(tp > 0.0 && ask - tp <= freeze)
            continue;
        }
      else
         continue;

      if(newSL <= 0.0)
         continue;

      ResetLastError();
      if(!trade.PositionModify(ticket, newSL, tp) || !TradeSucceeded())
         LogTradeError(StringFormat("SL güncelleme #%I64u (yeni SL=%s)", ticket, DoubleToString(newSL, g_digits)));
      else
         PrintFormat("[YÖNETİM] #%I64u SL güncellendi: %s -> %s", ticket,
                     DoubleToString(sl, g_digits), DoubleToString(newSL, g_digits));
     }
  }

//====================================================================
//                         HABER FİLTRESİ
//  Canlı: MT5 dahili ekonomik takvimi (CalendarValueHistory).
//  Strategy Tester: takvim fonksiyonları çalışmaz, CSV dosyası kullanılır.
//  CSV formatı: YYYY.MM.DD HH:MM,PARA_BIRIMI,ONEM(1-3),Başlık
//====================================================================
string TrimStr(string s)
  {
   StringTrimLeft(s);
   StringTrimRight(s);
   return(s);
  }

//--- Para birimi listesini hazırla
void InitNewsCurrencies()
  {
   ArrayResize(g_newsCurrencies, 0);
   string parts[];
   int n = StringSplit(InpNewsCurrencies, ',', parts);
   for(int i = 0; i < n; i++)
     {
      string c = TrimStr(parts[i]);
      StringToUpper(c);
      if(c == "")
         continue;
      int k = ArraySize(g_newsCurrencies);
      ArrayResize(g_newsCurrencies, k + 1);
      g_newsCurrencies[k] = c;
     }
  }

//--- Para birimi filtreye uyuyor mu?
bool CurrencyMatches(string cur)
  {
   if(ArraySize(g_newsCurrencies) == 0)
      return(true);
   cur = TrimStr(cur);
   StringToUpper(cur);
   if(cur == "" || cur == "ALL")
      return(true);
   for(int i = 0; i < ArraySize(g_newsCurrencies); i++)
      if(cur == g_newsCurrencies[i])
         return(true);
   return(false);
  }

//--- Listeye olay ekle
void AddNews(NewsEvent &arr[], const datetime t, const string cur, const int imp, const string title, const bool fromCsv)
  {
   int k = ArraySize(arr);
   ArrayResize(arr, k + 1, 256);
   arr[k].time       = t;
   arr[k].currency   = cur;
   arr[k].importance = imp;
   arr[k].title      = title;
   arr[k].fromCsv    = fromCsv;
  }

//--- Zamana göre sırala (insertion sort; zaten sıralı veride O(n))
void SortNews(NewsEvent &arr[])
  {
   int n = ArraySize(arr);
   for(int i = 1; i < n; i++)
     {
      NewsEvent key = arr[i];
      int j = i - 1;
      while(j >= 0 && arr[j].time > key.time)
        {
         arr[j + 1] = arr[j];
         j--;
        }
      arr[j + 1] = key;
     }
  }

//--- Takvim önem seviyesini 1-3'e çevir
int ImportanceToInt(const ENUM_CALENDAR_EVENT_IMPORTANCE imp)
  {
   switch(imp)
     {
      case CALENDAR_IMPORTANCE_HIGH:
         return(3);
      case CALENDAR_IMPORTANCE_MODERATE:
         return(2);
      case CALENDAR_IMPORTANCE_LOW:
         return(1);
      default:
         return(0);
     }
  }

//--- CSV dosyasından haberleri yükle
void LoadNewsCsv(NewsEvent &arr[])
  {
   if(InpNewsCsvFile == "")
      return;
   int flags = FILE_READ | FILE_TXT | FILE_ANSI | FILE_SHARE_READ;
   if(InpNewsCsvCommonFolder)
      flags |= FILE_COMMON;
   ResetLastError();
   int h = FileOpen(InpNewsCsvFile, flags);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("[BİLGİ] Haber CSV açılamadı (%s, ortak klasör=%s, hata=%d).",
                  InpNewsCsvFile, InpNewsCsvCommonFolder ? "evet" : "hayır", GetLastError());
      return;
     }
   int loaded = 0, bad = 0;
   while(!FileIsEnding(h))
     {
      string line = TrimStr(FileReadString(h));
      if(line == "" || StringGetCharacter(line, 0) == '#')
         continue;
      string f[];
      int n = StringSplit(line, ',', f);
      if(n < 3)
        { bad++; continue; }
      string ts = TrimStr(f[0]);
      StringReplace(ts, "-", ".");
      datetime t = StringToTime(ts);
      if(t <= 0)
        { bad++; continue; }
      if(InpNewsCsvTimeIsGMT)
         t += (datetime)BrokerOffsetSeconds(t);
      int imp = (int)StringToInteger(TrimStr(f[2]));
      if(imp < (int)InpNewsMinImportance)
         continue;
      string cur = TrimStr(f[1]);
      if(!CurrencyMatches(cur))
         continue;
      string title = (n >= 4) ? TrimStr(f[3]) : "Haber";
      AddNews(arr, t, cur, imp, title, true);
      loaded++;
     }
   FileClose(h);
   PrintFormat("[BİLGİ] Haber CSV yüklendi: %d olay (hatalı satır: %d).", loaded, bad);
  }

//--- Haber modülünü başlat
void InitNews()
  {
   InitNewsCurrencies();
   ArrayResize(g_news, 0);
   LoadNewsCsv(g_news);
   SortNews(g_news);
   g_newsStart = 0;
   UpdateCalendarNews(true);
   if(MQLInfoInteger(MQL_TESTER) && ArraySize(g_news) == 0)
      Print("[UYARI] Strategy Tester'da ekonomik takvim çalışmaz ve haber CSV'si boş. Haber filtresi bu testte ETKİSİZ.");
  }

//--- Canlıda ekonomik takvimden olayları çek (15 dk'da bir)
void UpdateCalendarNews(const bool force)
  {
   if(!InpUseNewsFilter || !InpNewsUseCalendar || MQLInfoInteger(MQL_TESTER))
      return;
   datetime now = TimeTradeServer();
   if(!force && now - g_lastCalendarUpdate < 900)
      return;
   g_lastCalendarUpdate = now;

   datetime from = now - 86400;
   datetime to   = now + 3 * 86400;
   NewsEvent fresh[];
   bool okAny = false;
   int  nc    = ArraySize(g_newsCurrencies);
   int  loops = (nc > 0) ? nc : 1;

   for(int c = 0; c < loops; c++)
     {
      MqlCalendarValue values[];
      ResetLastError();
      bool ok = (nc > 0) ? CalendarValueHistory(values, from, to, NULL, g_newsCurrencies[c])
                         : CalendarValueHistory(values, from, to);
      if(!ok)
        {
         PrintFormat("[UYARI] Ekonomik takvim okunamadı (%s). Hata=%d", (nc > 0) ? g_newsCurrencies[c] : "tümü", GetLastError());
         continue;
        }
      okAny = true;
      for(int i = 0; i < ArraySize(values); i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev))
            continue;
         if(ev.type == CALENDAR_TYPE_HOLIDAY || ev.time_mode != CALENDAR_TIMEMODE_DATETIME)
            continue;
         int imp = ImportanceToInt(ev.importance);
         if(imp < (int)InpNewsMinImportance)
            continue;
         string cur = (nc > 0) ? g_newsCurrencies[c] : "";
         MqlCalendarCountry country;
         if(cur == "" && CalendarCountryById(ev.country_id, country))
            cur = country.currency;
         AddNews(fresh, values[i].time, cur, imp, ev.name, false);
        }
     }

   if(!okAny)
     {
      g_lastCalendarUpdate = now - 840;   // 1 dk sonra tekrar dene, eski liste korunur
      return;
     }

//--- Listeyi yeniden kur: CSV olayları + taze takvim olayları
   NewsEvent merged[];
   for(int i = 0; i < ArraySize(g_news); i++)
      if(g_news[i].fromCsv)
         AddNews(merged, g_news[i].time, g_news[i].currency, g_news[i].importance, g_news[i].title, true);
   for(int i = 0; i < ArraySize(fresh); i++)
      AddNews(merged, fresh[i].time, fresh[i].currency, fresh[i].importance, fresh[i].title, false);
   SortNews(merged);

   ArrayResize(g_news, ArraySize(merged));
   for(int i = 0; i < ArraySize(merged); i++)
      g_news[i] = merged[i];
   g_newsStart = 0;
  }

//--- Geçmişte kalan olayları atla (zaman sadece ileri gider)
void PruneNews(const datetime now)
  {
   int n = ArraySize(g_news);
   while(g_newsStart < n && g_news[g_newsStart].time + InpNewsMinutesAfter * 60 < now)
      g_newsStart++;
  }

//--- Şu an haber penceresinde miyiz?
bool IsNewsBlocked(string &reason)
  {
   if(!InpUseNewsFilter)
      return(false);
   datetime now = TimeCurrent();
   PruneNews(now);
   for(int i = g_newsStart; i < ArraySize(g_news); i++)
     {
      datetime t = g_news[i].time;
      if(t - InpNewsMinutesBefore * 60 > now)
         break;                                 // sıralı liste: sonrakiler daha ileride
      if(now >= t - InpNewsMinutesBefore * 60 && now <= t + InpNewsMinutesAfter * 60)
        {
         reason = StringFormat("Haber: %s %s %s", g_news[i].currency, StringSubstr(g_news[i].title, 0, 22),
                               TimeToString(t, TIME_MINUTES));
         return(true);
        }
     }
   return(false);
  }

//--- Haber öncesi pozisyon kapatma (opsiyonel)
void CheckNewsClose()
  {
   if(!InpUseNewsFilter || !InpNewsClosePositions || CountPositions() == 0)
      return;
   datetime now = TimeCurrent();
   PruneNews(now);
   for(int i = g_newsStart; i < ArraySize(g_news); i++)
     {
      datetime t = g_news[i].time;
      if(t - now > InpNewsCloseMinutesBefore * 60)
         break;
      if(t >= now)
        {
         CloseAllPositions("Haber öncesi: " + g_news[i].currency + " " + g_news[i].title);
         return;
        }
     }
  }

//--- Panel için sıradaki haber metni
string NextNewsText()
  {
   if(!InpUseNewsFilter)
      return("filtre kapalı");
   datetime now = TimeCurrent();
   PruneNews(now);
   if(g_newsStart >= ArraySize(g_news))
      return("yakın haber yok");
   long mins = (long)(g_news[g_newsStart].time - now) / 60;
   return(StringFormat("%s %s (%I64d dk)", g_news[g_newsStart].currency,
                       StringSubstr(g_news[g_newsStart].title, 0, 16), mins));
  }

//====================================================================
//                         BİLGİ PANELİ
//====================================================================
void CreateLabel(const string name, const int x, const int y)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, " ");
  }

void CreatePanel()
  {
   string bg = PANEL_PREFIX + "BG";
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 330);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 18 * PANEL_LINES + 10);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'25,30,40');
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
   ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);

   for(int i = 0; i < PANEL_LINES; i++)
      CreateLabel(PANEL_PREFIX + "L" + (string)i, InpPanelX + 8, InpPanelY + 6 + i * 18);
  }

void SetLine(const int idx, const string text, const color clr = clrWhite)
  {
   string name = PANEL_PREFIX + "L" + (string)idx;
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
  }

void UpdatePanel(const bool force)
  {
   if(!g_panelEnabled)
      return;
   uint now = GetTickCount();
   if(!force && now - g_lastPanelTick < 500)
      return;
   g_lastPanelTick = now;

   double dayPL    = g_realizedToday + FloatingPL();
   double dayPLPct = (g_dayStartBalance > 0.0) ? dayPL / g_dayStartBalance * 100.0 : 0.0;
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd       = (g_peakEquity > 0.0) ? (g_peakEquity - equity) / g_peakEquity * 100.0 : 0.0;
   double atr      = 0.0;
   GetValue(hATR, 0, 1, atr, true);

   string reason = "";
   bool canTrade = CanOpenNewTrade(reason);
   color  stClr  = g_emergency ? clrRed : (canTrade ? clrLime : clrOrange);
   string tradesMax = (InpMaxTradesPerDay > 0) ? (string)InpMaxTradesPerDay : "-";
   string consecMax = (InpMaxConsecLosses > 0) ? (string)InpMaxConsecLosses : "-";

   SetLine(0, "XAUUSD Scalper  |  Magic " + (string)InpMagic, clrGold);
   SetLine(1, "Durum      : " + reason, stClr);
   SetLine(2, StringFormat("Gunluk K/Z : %.2f (%.2f%%)", dayPL, dayPLPct), dayPL >= 0.0 ? clrLime : clrTomato);
   SetLine(3, "Islem (gun): " + (string)g_tradesToday + " / " + tradesMax);
   SetLine(4, "Ard. zarar : " + (string)g_consecLosses + " / " + consecMax);
   SetLine(5, StringFormat("Spread     : %.1f pip (max %.1f)", SpreadPips(), InpMaxSpreadPips),
           SpreadPips() > InpMaxSpreadPips ? clrOrange : clrWhite);
   SetLine(6, StringFormat("ATR        : %.1f pip (min %.1f)", atr / g_pip, InpMinATRPips));
   SetLine(7, "Seans      : " + (IsTradingSession() ? "ACIK" : "KAPALI"));
   SetLine(8, "Pozisyon   : " + (string)CountPositions() + " / " + (string)InpMaxPositions);
   SetLine(9, StringFormat("Equity DD  : %.2f%% (max %.1f%%)", dd, InpMaxEquityDDPct), dd > InpMaxEquityDDPct * 0.7 ? clrOrange : clrWhite);
   string nr = "";
   bool newsNow = IsNewsBlocked(nr);
   SetLine(10, "Haber      : " + NextNewsText(), newsNow ? clrOrange : clrWhite);
   ChartRedraw();
  }
//+------------------------------------------------------------------+
