//+------------------------------------------------------------------+
//|                                                ExportBarsCsv.mq5 |
//|  Seçilen sembolün mum verisini (OHLC, tick hacmi, spread) CSV'ye |
//|  aktarır. Strateji araştırması / dış analiz için kullanılır.     |
//|  Çıktı: Terminal\Common\Files\<sembol>_<TF>.csv                  |
//+------------------------------------------------------------------+
#property copyright "XauusdScalperEA"
#property version   "1.00"
#property script_show_inputs

input ENUM_TIMEFRAMES InpTF   = PERIOD_M5;      // Zaman dilimi
input datetime        InpFrom = D'2023.01.01';  // Başlangıç tarihi
input datetime        InpTo   = D'2026.12.31';  // Bitiş tarihi

void OnStart()
  {
   MqlRates rates[];
   ResetLastError();
   int n = CopyRates(_Symbol, InpTF, InpFrom, InpTo, rates);
   if(n <= 0)
     {
      PrintFormat("[HATA] CopyRates başarısız. Hata=%d. Grafikte geçmişi kaydırıp yeterli veri yükleyin.", GetLastError());
      return;
     }
   string tf   = StringSubstr(EnumToString(InpTF), 7);
   string name = _Symbol + "_" + tf + ".csv";
   int h = FileOpen(name, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("[HATA] Dosya oluşturulamadı: %s hata=%d", name, GetLastError());
      return;
     }
   FileWriteString(h, StringFormat("# symbol=%s digits=%d point=%s\r\n", _Symbol, _Digits, DoubleToString(_Point, _Digits)));
   FileWriteString(h, "time,open,high,low,close,tick_volume,spread_points\r\n");
   for(int i = 0; i < n; i++)
      FileWriteString(h, StringFormat("%s,%s,%s,%s,%s,%I64d,%d\r\n",
                                      TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES),
                                      DoubleToString(rates[i].open, _Digits), DoubleToString(rates[i].high, _Digits),
                                      DoubleToString(rates[i].low, _Digits), DoubleToString(rates[i].close, _Digits),
                                      rates[i].tick_volume, rates[i].spread));
   FileClose(h);
   PrintFormat("[BİLGİ] %d mum yazıldı: Common\\Files\\%s", n, name);
  }
//+------------------------------------------------------------------+
