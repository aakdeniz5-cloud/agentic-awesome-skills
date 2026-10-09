//+------------------------------------------------------------------+
//|                                                ExportNewsCsv.mq5 |
//|  MT5 ekonomik takvim geçmişini XauusdScalperEA'nın Strategy      |
//|  Tester'da okuyabileceği CSV formatına aktaran script.           |
//|                                                                  |
//|  Çıktı satırı: YYYY.MM.DD HH:MM,PARA_BIRIMI,ONEM(1-3),Başlık     |
//|  Saatler broker SUNUCU saatidir (EA: InpNewsCsvTimeIsGMT=false). |
//+------------------------------------------------------------------+
#property copyright "XauusdScalperEA"
#property version   "1.00"
#property script_show_inputs

input datetime InpFrom          = D'2022.01.01'; // Başlangıç tarihi
input datetime InpTo            = D'2026.12.31'; // Bitiş tarihi
input string   InpCurrencies    = "USD";         // Para birimleri (virgülle)
input int      InpMinImportance = 2;             // Min önem (1=düşük, 2=orta, 3=yüksek)
input string   InpFileName      = "xau_news.csv"; // Dosya adı
input bool     InpCommonFolder  = true;          // Ortak klasöre yaz (Terminal\Common\Files)

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

void OnStart()
  {
   string parts[];
   int nc = StringSplit(InpCurrencies, ',', parts);
   if(nc <= 0)
     {
      Print("[HATA] Para birimi listesi boş.");
      return;
     }

   int flags = FILE_WRITE | FILE_TXT | FILE_ANSI;
   if(InpCommonFolder)
      flags |= FILE_COMMON;
   int h = FileOpen(InpFileName, flags);
   if(h == INVALID_HANDLE)
     {
      PrintFormat("[HATA] Dosya oluşturulamadı: %s hata=%d", InpFileName, GetLastError());
      return;
     }
   FileWriteString(h, "# time(server),currency,importance(1-3),title\r\n");

   int written = 0;
   for(int c = 0; c < nc; c++)
     {
      string cur = parts[c];
      StringTrimLeft(cur);
      StringTrimRight(cur);
      StringToUpper(cur);
      if(cur == "")
         continue;

      MqlCalendarValue values[];
      ResetLastError();
      if(!CalendarValueHistory(values, InpFrom, InpTo, NULL, cur))
        {
         PrintFormat("[HATA] Takvim okunamadı (%s). Hata=%d", cur, GetLastError());
         continue;
        }
      for(int i = 0; i < ArraySize(values); i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev))
            continue;
         if(ev.type == CALENDAR_TYPE_HOLIDAY || ev.time_mode != CALENDAR_TIMEMODE_DATETIME)
            continue;
         int imp = ImportanceToInt(ev.importance);
         if(imp < InpMinImportance)
            continue;
         string title = ev.name;
         StringReplace(title, ",", ";");
         FileWriteString(h, StringFormat("%s,%s,%d,%s\r\n",
                                         TimeToString(values[i].time, TIME_DATE | TIME_MINUTES), cur, imp, title));
         written++;
        }
     }
   FileClose(h);
   PrintFormat("[BİLGİ] %d olay %s dosyasına yazıldı (%s).", written, InpFileName,
               InpCommonFolder ? "Common\\Files" : "MQL5\\Files");
  }
//+------------------------------------------------------------------+
