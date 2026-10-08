# XauusdScalperEA (MQL5)

XAUUSD için M1/M5 scalping Expert Advisor. Martingale, grid ve averaging yok. Her işlem SL ve TP ile birlikte açılır. Varsayılan olarak aynı anda tek pozisyon açılır.

> Bu EA bir başlangıç şablonudur, kâr garantisi vermez. Gerçek hesapta çalıştırmadan önce demo hesapta ve gerçek tick verisiyle test edin.

## Kurulum

1. `XauusdScalperEA.mq5` dosyasını `MQL5/Experts/` klasörüne kopyalayın.
2. MetaEditor'da açıp **F7** ile derleyin.
3. Backtest'te haber filtresi kullanmak istiyorsanız `ExportNewsCsv.mq5` dosyasını `MQL5/Scripts/` klasörüne kopyalayıp derleyin ve bir kez çalıştırın. Ayrıntılar aşağıda, [Haber filtresi](#haber-filtresi) bölümünde.
4. XAUUSD grafiğine ekleyin (grafiğin zaman dilimi önemli değil, `InpEntryTF` kullanılır). "Algo Trading" açık olmalı.

## Strateji özeti

| Adım | Kural |
|---|---|
| Trend | Trend TF'de (M15) son kapanmış mumda EMA50 > EMA200 ise sadece alış, EMA50 < EMA200 ise sadece satış. İsteğe bağlı olarak kapanış fiyatı da EMA200'ün doğru tarafında olmalı. |
| Giriş | Giriş TF'de (M5/M1) kapanmış mumlarda EMA9/EMA21 kesişimi. Alışta RSI(7) 50–75 arası, satışta 25–50 arası. |
| Haber | Seçilen para birimlerindeki önemli haberlerden 30 dk önce ve 30 dk sonra yeni işlem açılmaz. İsterseniz açık pozisyonlar haberden önce kapatılır. |
| Volatilite | ATR(14), son 100 mumun ortalama ATR'sinin 0,8 katından düşükse işlem açılmaz. Böylece filtre altının fiyat seviyesinden bağımsız çalışır. İsteğe bağlı olarak sabit pip alt ve üst sınırları da kullanılabilir. |
| SL / TP | SL = ATR × 1.5, TP = SL × 1.5. Broker'ın StopLevel ve FreezeLevel değerleri ile spread hesaba katılır. |
| Yönetim | Fiyat TP mesafesinin %50'sine gelince SL girişe (+kilit pip) çekilir. Ardından ATR trailing devreye girer. |
| Kontrol sıklığı | Sinyaller sadece yeni mum açılışında, BE ve trailing her tick'te kontrol edilir. |

### Pip tanımı (4/5 hane uyumu)
Digits değeri 3 veya 5 ise pip = point × 10, diğer durumlarda pip = point. XAUUSD için bu, 2 haneli (2350.15) ve 3 haneli (2350.153) broker'ların ikisinde de **1 pip = 0.01$** demek. Örneğin 35 pip spread 0.35$, 80 pip ATR 0.80$ olur. Farklı bir tanım kullanmak isterseniz `InpPipSizeOverride` ile değiştirebilirsiniz (örn. 0.1).

## Input parametreleri

### Genel
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpMagic | 20261008 | EA'nın pozisyonlarını ayırt eden numara. |
| InpComment | XAU_Scalper | Emir yorumu. |
| InpMaxPositions | 1 | Bu sembol ve magic için aynı anda açık olabilecek pozisyon sayısı. |
| InpPipSizeOverride | 0 | 0 ise pip otomatik hesaplanır, değilse fiyat cinsinden pip büyüklüğü. |

### Zaman dilimleri, trend ve giriş
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpEntryTF | M5 | Giriş sinyali ve ATR zaman dilimi. |
| InpTrendTF | M15 | Trend filtresi zaman dilimi. |
| InpTrendFastEMA / InpTrendSlowEMA | 50 / 200 | Trend EMA'ları. |
| InpRequirePriceVsSlowEMA | true | Kapanış fiyatı da EMA200'ün trend yönündeki tarafında olmalı. |
| InpEntryMode | Kesişim | **Kesişim:** EMA9/21 kesişimi. **Pullback:** EMA9 > EMA21 iken mum EMA21'e kadar geri çekilir, trend yönünde ve EMA9'un ötesinde kapanır (satışta tersi). |
| InpPullbackATR | 0.2 | Pullback modunda mumun EMA21'e "değdi" sayılması için tolerans (ATR × oran). |
| InpFastEMA / InpSlowEMA | 9 / 21 | Kesişim ve pullback EMA'ları. |
| InpAppliedPrice | Close | EMA ve RSI'ın hesaplandığı fiyat. |
| InpRSIPeriod | 7 | RSI periyodu. |
| InpRSIBuyMin / InpRSIBuyMax | 50 / 75 | Alış için RSI aralığı. |
| InpRSISellMax / InpRSISellMin | 50 / 25 | Satış için RSI aralığı. |

### Volatilite ve SL/TP
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpATRPeriod | 14 | ATR periyodu. |
| InpMinATRPips | 0 | Sabit alt sınır, pip cinsinden. 0 = kapalı. Fiyat seviyesi değiştikçe anlamını yitirdiği için varsayılan olarak kapalı. |
| InpMaxATRPips | 0 | Bu değerin üstünde işlem açılmaz, örneğin haber anlarındaki aşırı oynaklık için. 0 = kapalı. |
| InpMinATRRatio | 0.8 | ATR, ortalama ATR'nin bu katından düşükse işlem açılmaz. 0 = kapalı. |
| InpATRAvgPeriod | 100 | Ortalama ATR'nin hesaplandığı mum sayısı. |

### Ek giriş filtreleri (isteğe bağlı, hepsi varsayılan kapalı)
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpRequireCloseBeyondSlow | false | Sinyal mumu EMA21'in doğru tarafında kapanmalı. |
| InpTrendSlopeBars | 0 | Trend TF'deki EMA50, N mum öncesine göre trend yönünde eğimli olmalı. 0 = kapalı, test için 3–5 deneyin. |
| InpUseADX / InpADXPeriod / InpADXMin | false / 14 / 20 | Giriş TF'de ADX bu değerin altındaysa (yatay piyasa) işlem açılmaz. |
| InpSLATRMult | 1.5 | SL = ATR × çarpan. |
| InpRiskReward | 1.5 | TP = SL × oran. |
| InpMinSLPips | 50 | SL en az bu kadar olur. Çok dar SL'nin spread yüzünden tetiklenmesini önler. |
| InpMaxSLPips | 0 | SL bu değeri aşarsa işlem atlanır. 0 = kapalı. |

### Breakeven ve trailing
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpUseBreakeven | true | Breakeven açık/kapalı. |
| InpBETriggerPct | 50 | Kâr, TP mesafesinin yüzde kaçına ulaşınca SL girişe çekilir. |
| InpBELockPips | 2 | SL, girişin bu kadar pip kârlı tarafına konur (komisyon ve spread için). |
| InpUseTrailing | true | ATR trailing açık/kapalı. |
| InpTrailATRMult | 1.5 | Trailing mesafesi = ATR × çarpan. |
| InpTrailStartR | 1.0 | Trailing, kâr ilk risk mesafesinin (R) bu katına ulaşınca başlar. 0 = hemen başlar. |
| InpTrailStepATR | 0.25 | SL en az ATR × oran kadar ilerlemeden güncellenmez. |
| InpTrailAfterBEOnly | true | Trailing sadece breakeven'dan sonra başlar. |

### Lot
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpLotMode | Risk % | Risk yüzdesi veya sabit lot. |
| InpRiskPercent | 0.5 | İşlem başına bakiyenin yüzde kaçı riske edilir. Lot, `OrderCalcProfit` ile SL mesafesine göre hesaplanır. |
| InpFixedLot | 0.01 | Sabit lot modunda kullanılan lot. |
| InpSkipIfMinLotTooRisky | true | Hesaplanan lot broker'ın min lotundan küçükse işlem açılmaz, böylece risk aşılmaz. |

Lot, broker'ın lot adımına göre aşağı yuvarlanır ve min/max lot sınırlarına çekilir. Gereken teminat serbest teminatın %90'ını aşarsa lot düşürülür.

### Günlük limitler ve acil durdurma
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpMaxDailyLossPct | 2.0 | Gerçekleşen ve yüzen K/Z toplamı, gün başı bakiyesinin %2'si kadar zarara ulaşırsa o gün işlem durur. |
| InpCloseOnDailyLoss | true | Limit aşılınca açık pozisyonlar da kapatılır. |
| InpMaxTradesPerDay | 10 | Günlük en fazla işlem sayısı. |
| InpMaxConsecLosses | 3 | O gün art arda bu kadar zarar gelirse günün kalanında işlem açılmaz. |
| InpUseEquityStop | true | Equity acil durdurma açık/kapalı. |
| InpMaxEquityDDPct | 10 | Equity, ulaştığı zirveden %10 düşerse tüm pozisyonlar kapanır ve EA kilitlenir. |
| InpResetEmergency | false | Kilidi kaldırmak için true yapıp EA'yı yeniden yükleyin, sonra tekrar false yapın. |

Gün sınırı broker sunucu saatiyle belirlenir. Zirve equity ve acil durum kilidi terminal global değişkenlerinde tutulur, bu yüzden terminal yeniden başlatılsa da korunur.

### Piyasa filtreleri
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpMaxSpreadPips | 35 | Spread bu değerin üstündeyse işlem açılmaz (0.35$). |
| InpMaxSlippagePoints | 30 | En fazla kayma (deviation), point cinsinden. |
| InpBrokerGMTOffset | 2 | Sunucu saatinin **kış saatindeki** GMT farkı. |
| InpAutoUSDST | true | ABD yaz saati döneminde (Mart'ın 2. Pazarı – Kasım'ın 1. Pazarı) farka otomatik +1 ekler. Çoğu altın broker'ı kışın GMT+2, yazın GMT+3 kullanır. Broker'ınız sabit saatteyse false yapın. |
| InpUseLondon, Start/End | true, 07–16 GMT | Londra seansı. |
| InpUseNewYork, Start/End | true, 12–21 GMT | New York seansı. |
| InpFridayFilter / InpFridayStopHourGMT | true / 19 | Cuma bu saatten sonra yeni işlem açılmaz. Hafta sonu zaten kapalıdır. |
| InpCloseBeforeWeekend / InpFridayCloseHourGMT | false / 20 | İsterseniz Cuma bu saatte açık pozisyonları kapatır. |

### Haber filtresi
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpUseNewsFilter | true | Haber filtresi açık/kapalı. |
| InpNewsMinImportance | Sadece yüksek | Hangi önem seviyesindeki haberlerin dikkate alınacağı. |
| InpNewsCurrencies | USD | Virgülle ayrılmış para birimleri, örneğin `USD,EUR,CNY`. Altını en çok USD haberleri etkiler. |
| InpNewsMinutesBefore / After | 30 / 30 | Haberden bu kadar dakika önce ve sonra yeni işlem açılmaz. |
| InpNewsClosePositions | false | Habere `InpNewsCloseMinutesBefore` dakika kala açık pozisyonları kapatır. |
| InpNewsCloseMinutesBefore | 5 | Kapatmanın habere kaç dakika kala yapılacağı. |
| InpNewsUseCalendar | true | Canlı ve demo hesapta MT5'in dahili ekonomik takvimini kullanır. Takvim 15 dakikada bir, önceki 1 gün ile sonraki 3 gün için güncellenir. |
| InpNewsCsvFile | xau_news.csv | Haber CSV dosyası. Boş bırakılırsa CSV kullanılmaz. Canlıda takvimle birlikte kullanılabilir, örneğin takvimde olmayan bir olayı elle eklemek için. |
| InpNewsCsvCommonFolder | true | CSV ortak klasörde aranır (`Terminal\Common\Files`). Bu klasöre yerel tester ajanları da erişebilir. |
| InpNewsCsvTimeIsGMT | false | CSV saatleri GMT ise true yapın. Varsayılan sunucu saatidir. |

**Önemli:** MT5'in takvim fonksiyonları (`CalendarValueHistory` vb.) Strategy Tester'da **çalışmaz**. Backtest'te haber filtresinin etkili olması için CSV gerekir:

1. Canlı terminalde (demo hesap yeterli) `ExportNewsCsv` script'ini çalıştırın. Örnek ayarlar: tarih aralığı 2022–2026, para birimi USD, min önem 2.
2. Script, broker'ın takvim geçmişini sunucu saatiyle `Common\Files\xau_news.csv` dosyasına yazar.
3. EA bu dosyayı testte otomatik okur. CSV yoksa veya boşsa günlüğe "Haber filtresi bu testte ETKİSİZ" uyarısı yazılır.

CSV formatı (`xau_news_sample.csv` örneğine bakın):
```
# time,currency,importance(1-3),title
2025.01.10 15:30,USD,3,Nonfarm Payrolls
```

### Panel
Panel günlük K/Z, işlem sayısı, art arda zarar, spread, ATR, seans, pozisyon sayısı, equity DD, sıradaki haber ve durumu (neden işlem açılmadığı) gösterir. Optimizasyon ve görsel olmayan testlerde hız için kapalıdır.

## Araştırma için mum verisi

`ExportBarsCsv.mq5` script'i, grafiğin sembolüne ait mum verisini (OHLC, tick hacmi, spread) `Common\Files\<sembol>_<TF>.csv` dosyasına yazar. Bu dosya, stratejiyi MT5 dışında, örneğin Python ile, hızlıca analiz etmek için kullanılır. Script'i `MQL5/Scripts/` klasörüne koyup derleyin ve XAUUSD grafiğinde çalıştırın. Çalıştırmadan önce grafikte geçmişi geriye kaydırıp yeterli veri yükleyin.

## Backtest ayarları

- **Model:** Every tick based on real ticks. Altın için diğer modeller spread'i ve kaymayı gerçekçi yansıtmaz.
- **Haber CSV'si:** Testten önce `ExportNewsCsv` ile oluşturun. Filtreyi açık ve kapalı olarak ayrı ayrı test edip farkı görün.
- **Veri:** İşlem yapacağınız broker'ın kendi tick verisi. En az 2 yıl kullanın, mümkünse 2022–2025 gibi farklı rejimleri içersin.
- **Gecikme:** "Random delay" veya 50–200 ms sabit gecikme ile de test edin.
- **Komisyon ve swap:** Hesap tipinizinkiyle aynı olsun. ECN hesapta lot başı komisyon, scalping sonucunu büyük ölçüde değiştirir.
- **Başlangıç bakiyesi:** Gerçek hesabınıza yakın olsun. Küçük bakiyede min lot, riskin %0.5'ini aşabilir ve EA bu işlemleri atlar.
- **Bakılacak metrikler:** Profit factor (en az 1.3), expectancy (işlem başı ortalama net kâr, komisyon sonrası), maksimum relatif drawdown, Recovery factor, işlem sayısı (istatistiksel anlam için en az 200–300) ve aylık sonuçların tutarlılığı.

## Optimizasyon önerisi

Az sayıda ve geniş adımlı parametre optimize edin. Parametre sayısı arttıkça overfitting riski de artar.

| Öncelik | Parametre | Önerilen aralık / adım |
|---|---|---|
| 1 | InpSLATRMult | 1.0 – 2.5 / 0.25 |
| 1 | InpRiskReward | 1.0 – 2.5 / 0.25 |
| 1 | InpMinATRRatio | 0.6 – 1.2 / 0.1 |
| 2 | InpEntryTF | M1, M5 |
| 2 | InpBETriggerPct | 30 – 80 / 10 |
| 2 | InpTrailStartR / InpTrailATRMult | 0.75 – 1.25 / 0.25 ve 1.0 – 2.0 / 0.5 (veya trailing kapalı/açık) |
| 3 | Seans saatleri | Sadece Londra, sadece NY, ikisi birden |
| 3 | InpNewsMinutesBefore / After | 15, 30, 60 (sadece birkaç değer) |
| 3 | InpMaxSpreadPips | Broker'ın tipik spread'inin 1.3–1.8 katı |

**Sabit bırakın:** EMA 9/21/50/200 ve RSI(7) eşiklerini optimize etmeyin. Bunlar stratejinin mantığını tanımlar ve onları sonuca göre ayarlamak overfitting'in en yaygın kaynağıdır. Risk yüzdesi ve günlük limitler optimize edilecek parametreler değil, risk kararlarıdır.

**Kriter:** "Balance max" yerine **"Custom max"** seçin. EA'nın `OnTester` skoru (PF − 1) × √işlem sayısı / max(Equity DD %, 1) olarak hesaplanır. `InpTesterMinTrades` (varsayılan 100) değerinden az işlem yapan ayarlar 0 puan alır. Tek bir zirve değer yerine, komşu parametre değerlerinde de iyi sonuç veren geniş bir **plato** bölgesi arayın.

## Walk-forward test (overfitting'den kaçınmak için)

1. **Veriyi bölün:** Örneğin 3 yıllık veriyi kullanın.
2. **Kayan pencere:** 6 ay in-sample (IS) optimizasyonun ardından 2 ay out-of-sample (OOS) test yapın. Pencereyi 2 ay kaydırıp tekrarlayın, böylece yaklaşık 12–15 pencere elde edilir.
3. Her IS döneminde plato bölgesinden parametre seçin ve bunları **hiç değiştirmeden** OOS döneminde çalıştırın.
4. Bütün OOS sonuçlarını birleştirip tek bir özsermaye eğrisi olarak değerlendirin. **Walk-forward efficiency** (yıllıklandırılmış OOS kârı / IS kârı) en az %50 olmalı.
5. MT5 tester'daki **Forward** seçeneği (1/4 veya 1/3) hızlı bir ilk kontrol sağlar ama tam walk-forward yerine geçmez.
6. **Ek kontroller:**
   - Komisyonu ve spread'i %50 artırarak stres testi yapın. Strateji hâlâ kârlı olmalı.
   - Farklı bir broker'ın tick verisiyle test edin.
   - İşlem sırasını karıştıran Monte Carlo analiziyle olası en kötü drawdown'u görün.
   - Seçilen parametrelerin ±%20 değişiminde sonuç dramatik şekilde bozulmamalı.
7. **Canlıya geçiş:** En az 1–2 ay demo veya küçük bir hesapta (min risk) çalıştırın. Sonuçları backtest istatistikleriyle (ortalama işlem, kazanma oranı, kayma) karşılaştırın.

## Bilinen sınırlamalar

- Yaz saati otomatiği ABD takvimine göre çalışır. Broker'ınız farklı bir kural uyguluyorsa `InpAutoUSDST=false` yapıp farkı elle güncelleyin.
- Takvim olmayan beklenmedik haberleri (ör. açıklamalar, jeopolitik gelişmeler) haber filtresi yakalamaz. Bunlar için `InpMaxATRPips` ve spread filtresi kısmi koruma sağlar.
- Takvimin kaydettiği haber saatleri sonradan değişmiş olabilir. Backtest'teki haber verisi canlıdakiyle birebir aynı olmayabilir.
- Equity acil durdurma hesabın toplam equity değerine bakar. Aynı hesapta başka EA'lar varsa onların zararları da hesaba katılır.
- Art arda zarar sayacı her gün sıfırlanır.
