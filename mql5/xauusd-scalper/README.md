# XauusdScalperEA (MQL5)

XAUUSD için M1/M5 scalping Expert Advisor. Martingale, grid ve averaging yok. Her işlem SL ve TP ile birlikte açılır. Varsayılan olarak aynı anda tek pozisyon açılır.

> Bu EA bir başlangıç şablonudur, kâr garantisi vermez. Gerçek hesapta çalıştırmadan önce demo hesapta ve gerçek tick verisiyle test edin.

## Kurulum

1. `XauusdScalperEA.mq5` dosyasını `MQL5/Experts/` klasörüne kopyalayın.
2. MetaEditor'da açıp **F7** ile derleyin.
3. XAUUSD grafiğine ekleyin (grafiğin zaman dilimi önemli değil, `InpEntryTF` kullanılır). "Algo Trading" açık olmalı.

## Strateji özeti

| Adım | Kural |
|---|---|
| Trend | Trend TF'de (M15) son kapanmış mumda EMA50 > EMA200 ise sadece alış, EMA50 < EMA200 ise sadece satış. İsteğe bağlı olarak kapanış fiyatı da EMA200'ün doğru tarafında olmalı. |
| Giriş | Giriş TF'de (M5/M1) kapanmış mumlarda EMA9/EMA21 kesişimi. Alışta RSI(7) 50–75 arası, satışta 25–50 arası. |
| Volatilite | ATR(14) `InpMinATRPips` altındaysa işlem açılmaz. İsteğe bağlı bir üst sınır da var. |
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
| InpFastEMA / InpSlowEMA | 9 / 21 | Kesişim EMA'ları. |
| InpAppliedPrice | Close | EMA ve RSI'ın hesaplandığı fiyat. |
| InpRSIPeriod | 7 | RSI periyodu. |
| InpRSIBuyMin / InpRSIBuyMax | 50 / 75 | Alış için RSI aralığı. |
| InpRSISellMax / InpRSISellMin | 50 / 25 | Satış için RSI aralığı. |

### Volatilite ve SL/TP
| Parametre | Varsayılan | Açıklama |
|---|---|---|
| InpATRPeriod | 14 | ATR periyodu. |
| InpMinATRPips | 80 | Bu değerin altında işlem açılmaz (0.80$). |
| InpMaxATRPips | 0 | Bu değerin üstünde işlem açılmaz, örneğin haber anlarındaki aşırı oynaklık için. 0 = kapalı. |
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
| InpTrailATRMult | 1.0 | Trailing mesafesi = ATR × çarpan. |
| InpTrailStepPips | 5 | SL en az bu kadar ilerlemeden güncellenmez. Gereksiz modify isteklerini engeller. |
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
| InpBrokerGMTOffset | 2 | Sunucu saatinin GMT'ye farkı. **Yaz/kış saati geçişinde güncelleyin** (genellikle kışın +2, yazın +3). |
| InpUseLondon, Start/End | true, 07–16 GMT | Londra seansı. |
| InpUseNewYork, Start/End | true, 12–21 GMT | New York seansı. |
| InpFridayFilter / InpFridayStopHourGMT | true / 19 | Cuma bu saatten sonra yeni işlem açılmaz. Hafta sonu zaten kapalıdır. |
| InpCloseBeforeWeekend / InpFridayCloseHourGMT | false / 20 | İsterseniz Cuma bu saatte açık pozisyonları kapatır. |

### Panel
Panel günlük K/Z, işlem sayısı, art arda zarar, spread, ATR, seans, pozisyon sayısı, equity DD ve durumu (neden işlem açılmadığı) gösterir. Optimizasyon ve görsel olmayan testlerde hız için kapalıdır.

## Backtest ayarları

- **Model:** Every tick based on real ticks. Altın için diğer modeller spread'i ve kaymayı gerçekçi yansıtmaz.
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
| 1 | InpMinATRPips | 40 – 160 / 20 (broker ve TF'ye bağlı) |
| 2 | InpEntryTF | M1, M5 |
| 2 | InpBETriggerPct | 30 – 80 / 10 |
| 2 | InpTrailATRMult | 0.5 – 2.0 / 0.25 (veya trailing kapalı/açık) |
| 3 | Seans saatleri | Sadece Londra, sadece NY, ikisi birden |
| 3 | InpMaxSpreadPips | Broker'ın tipik spread'inin 1.3–1.8 katı |

**Sabit bırakın:** EMA 9/21/50/200 ve RSI(7) eşiklerini optimize etmeyin. Bunlar stratejinin mantığını tanımlar ve onları sonuca göre ayarlamak overfitting'in en yaygın kaynağıdır. Risk yüzdesi ve günlük limitler optimize edilecek parametreler değil, risk kararlarıdır.

**Kriter:** "Balance max" yerine "Custom max" (ör. Recovery factor veya Profit factor × √işlem sayısı) ya da "Balance + max Profit Factor" seçin. Tek bir zirve değer yerine, komşu parametre değerlerinde de iyi sonuç veren geniş bir **plato** bölgesi arayın.

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

- GMT farkı manuel girilir. Yaz/kış saati geçişinde güncellenmezse seans saatleri bir saat kayar.
- Haber filtresi yoktur. NFP, CPI ve FOMC gibi yüksek etkili haberlerde altın sert hareket eder. `InpMaxATRPips` ve spread filtresi kısmi koruma sağlar.
- Equity acil durdurma hesabın toplam equity değerine bakar. Aynı hesapta başka EA'lar varsa onların zararları da hesaba katılır.
- Art arda zarar sayacı her gün sıfırlanır.
