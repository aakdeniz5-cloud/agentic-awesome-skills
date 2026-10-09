# ASLAN Vur-Kaç M5 v2.80 LIVE

Kullanıcının v2.63 grid EA'sının canlı hesap için sağlamlaştırılmış sürümü. Değişiklikler, EC Markets'in demo ve canlı hesap farkları hakkındaki notlarına ve XAUUSD.n sembol özelliklerine dayanıyor.

> Bu değişiklikler canlı hesapta zarar ettiren maliyetleri azaltmak ve ölçmek içindir. Kâr garantisi vermez. Önce küçük bir canlı hesapta, minimum lotla deneyin.

## XAUUSD.n (EC Markets) özellikleri ve etkileri

| Özellik | Değer | EA'ya etkisi |
|---|---|---|
| Digits | 2 | 1 point = 0,01 $. `AutoScalePoints` bu sembolde ×1 kalır. |
| Komisyon | 3 USD / lot / işlem | Açılış + kapanış = 6 USD/lot = **6 point**. Grid ve SL mesafelerine maliyet olarak eklenir. |
| Stop seviyesi | 0 | Mesafe kısıtı yok. Kod yine de StopLevel ve FreezeLevel değerlerini okur. |
| Spread | Değişken | Ortalaması izlenir, sıçramalarda bekleyen emirler silinir. |
| İşlem saatleri | 01:05–23:59 (Cuma 23:55) | Günlük aradan önce pozisyonlar kapatılır. Açılıştan sonraki 30 dk boyunca emir konmaz. |
| Swap | Long −57,22 / Short +23,55 point, Çarşamba ×3 | 1 lot long için gecelik ≈ −57 $. Rollover öncesi kapatma varsayılan olarak açık. |
| Emir tipleri | Market, Limit, Stop, Stop Limit | — |

## EC Markets maddeleri → kod değişikliği

| # | Konu | v2.70'teki karşılığı |
|---|---|---|
| 1–2 | Demo simülasyon, kayma | Her gerçekleşmede istenen ve gerçekleşen fiyat, kayma, spread ve komisyon `Common\Files\ASLAN_exec_<hesapNo>.csv` dosyasına yazılır. Ekranda ortalama ve en büyük kayma görünür. Demo ile canlı hesap bu dosyalarla karşılaştırılır. |
| 3 | Spread sıçraması, rollover, haber | Spread `MaximumSpreadPoints` (80 → **35**) değerini veya ortalamanın 2 katını aşarsa, rollover sırasında, seans açılışında ya da yüksek önemli USD haberinde **bekleyen emirler silinir ve yenisi konmaz**. |
| 4 | Komisyon | Net hesaplar kapanış komisyonunu da içerir (`CountClosingCommission`). Grid aralığı ve SL, (spread + komisyon) maliyetinin katından küçük olamaz. |
| 5 | Stop / freeze seviyesi | Açılışta günlüğe yazılır. Emir fiyatları zaten bu seviyelere göre ayarlanıyor. |
| 6 | Gecikme | Pozisyon komisyonu her tick'te geçmiş taranarak değil önbellekten okunur. Daha az sunucu yükü, daha hızlı tick işleme. VPS önerisi geçerli. |
| 7 | Marj ve drawdown | Marj seviyesi %1000'in altındaysa yeni emir konmaz. Açık + bekleyen toplam lot en fazla 0,30. |

## Yeni ayarlar (LIVE PROTECTION)

| Ayar | Varsayılan | Açıklama |
|---|---|---|
| AutoScalePoints | true | 3/5 basamaklı fiyatta point ayarlarını ×10 yapar. |
| CommissionPerLotPerSide | 3.0 | Komisyon, USD / lot / işlem. |
| GridSpreadMultiplier | 2.0 | Grid aralığı ≥ (ortalama spread + komisyon) × 2. |
| SLSpreadMultiplier | 3.0 | SL ≥ (ortalama spread + komisyon) × 3. |
| SpreadAverageTicks | 300 | Spread ortalamasının hesaplandığı tick sayısı. |
| SpreadSpikeMultiplier | 2.0 | Spread ortalamanın bu katını aşarsa sıçrama sayılır. |
| DeletePendingWhenBlocked | true | Engel varken bekleyen emirleri siler. |
| UseRolloverFilter / Before / After | true / 15 / 30 | Sunucu gece yarısı çevresinde emir konmaz. |
| CloseBeforeRollover | true | Rollover penceresi başlayınca (23:45) açık pozisyonları kapatır. |
| SessionOpenSkipMinutes | 30 | 30 dakikadan uzun tick boşluğundan (açılış veya günlük ara) sonra X dk emir konmaz. |
| UseNewsFilter / NewsCurrencies / Before / After | true / USD / 15 / 15 | Yüksek önemli haberler. Sadece canlı ve demo hesapta çalışır, Strategy Tester'da çalışmaz. |
| CountClosingCommission | true | Net kâr ve zarar hesaplarına kapanış komisyonunu ekler. |
| MinMarginLevelPercent | 1000 | Marj seviyesi bunun altındaysa yeni emir konmaz. |
| MaxTotalLots | 0.30 | Açık + bekleyen toplam lot sınırı. |
| LogExecutions | true | Gerçekleşme günlüğü. |

## v2.70 backtest sonucu ve v2.71 değişikliği

2026.05–2026.10 döneminde, 10.000 $ başlangıç bakiyesiyle, gerçek tick verisiyle yapılan v2.70 testinin sonucu:
- **−1.900 $** net, 7.059 işlem, profit factor 0,82.
- Komisyon −635 $.
- Fiyat hareketinden sonuç −1.265 $ (spread ve kayma dahil).
- **Stop emirleri istenen fiyattan ortalama 10 point (medyan 5) kötü doldu.** 0,03 lotta bu yaklaşık 2.100 $ eder ve en büyük maliyet kalemi.

v2.71 bu maliyeti hedefliyor:

| Ayar | Varsayılan | Açıklama |
|---|---|---|
| UseStopLimit | true | Buy/Sell Stop yerine Buy/Sell **Stop Limit** kullanılır. Fiyat stop seviyesine gelince stop fiyatında veya daha iyisinde bir limit emri oluşur, yani **kayma sıfır** olur. Sunucu reddederse otomatik olarak normal Stop emirlerine dönülür. |
| StopLimitOffsetPoints | 1 | Limit fiyatı stop fiyatından bu kadar iyi. MT5 kuralı: Buy Stop Limit'te limit stop'un altında olmalıdır. |
| StopLimitWaitSeconds | 30 | Tetiklenen emir bu süre içinde dolmazsa iptal edilir. Bu, fiyatın geri gelmeden kaçtığı ve işlemin kaçırıldığı anlamına gelir. |

Bedeli: hızlı ve tek yönlü hareketlerde işlem açılmaz. Bu stratejinin kazandıran işlemleri tam o hareketler olabilir. Sonuç ancak test edilerek görülür. Test bittiğinde Journal'daki `ASLAN EXEC SUMMARY` satırı ortalama kaymayı ve kaçırılan emir sayısını gösterir.

### v2.71 test sonuçları ve v2.72 düzeltmesi

| Test | Net | PF | İşlem | Maks. DD | Not |
|---|---|---|---|---|---|
| A (v2.71 varsayılan) | −1.597 $ | 0,85 | 7.463 | %17,7 | Stop Limit fiilen çalışmadı (7.463 girişin 12'si) |
| B (orijinal mesafe) | −2.244 $ | 0,79 | 8.628 | %22,8 | Stop Limit yine çalışmadı |
| C (Stop Limit kapalı) | −1.984 $ | 0,81 | 7.086 | %21,1 | |
| D | −2.197 $ | 0,81 | 7.781 | %22,3 | Orijinal v2.63 yerine v2.71 + v2.63 seti çalıştırıldı |

Bu testlerde stop emirleri istenen fiyattan ortalama yaklaşık 10 point kötü doldu. v2.71'de tek bir Stop Limit reddi, EA'yı test boyunca kalıcı olarak normal Stop'a döndürüyordu. **v2.72'de ret yalnızca o emri etkiler.** Ret sebebi (retcode, fiyatlar) Journal'a yazılır ve `ASLAN EXEC SUMMARY` satırında kabul edilen ve reddedilen Stop Limit sayıları görünür.

### v2.80: biriktirme koruması

Fusion canlı hesapta görülen davranış: fiyat yükselirken 4 alış pozisyonu üst üste açıldı (4182,00 → 4182,47), fiyat dönünce hepsi birlikte zarara geçti. Ayrıca karışık sepette, ters yöndeki pozisyonlar zarardayken yeni pozisyon eklendi.

| Ayar | Varsayılan | Açıklama |
|---|---|---|
| NoAddWhileBasketLoss | true | Sepet net zarardayken yeni pozisyon açılmaz. Sunucudaki bekleyen emirler de silinir, çünkü koşul bozulsa da tetiklenebilirler. |
| MaxPositionsPerSide | 2 | Aynı yönde en fazla 2 açık pozisyon. Dolan yönün bekleyen emirleri silinir. |
| CloseOppositeOnSwitch | true | Yön değişince ters yöndeki pozisyonlar kapatılır. Zarardaki pozisyonlar taşınarak üstüne ekleme yapılmaz. |

Dosya adı v2.80, çünkü kullanıcının bilgisayarında v276–v278 adlı başka dosyalar var.

Setler:
- `ASLAN_FUSION_v280_canli_001lot.set`: Fusion canlı hesap için
- `ASLAN_J_v280_tester.set`: tester için

### v2.75: gecikme (latency) koruması

Canlı hesapta her istek sunucuya gidip gelir. EC Markets yöneticisinin 6. maddesi bu gecikmeyle ilgiliydi. v2.75'teki değişiklikler:

| Sorun | v2.75 çözümü |
|---|---|
| Basket kapatılırken pozisyonlar sırayla kapatılıyordu. Her istek bir öncekinin cevabını beklediği için 12 pozisyonda, 100 ms gecikmeyle, son pozisyon ~1,2 sn geç ve kayarak kapanıyordu. | Kapatma ve bekleyen emir silme istekleri **aynı anda (async)** gönderilir (`UseAsyncBatch`). Aynı istek `ResendAfterMs` süresi dolmadan tekrar gönderilmez. |
| SL değişiklikleri (başa baş, basket SL, trailing) her tick'te tekrar tekrar gönderilebiliyordu. Bağlantı yavaşken istek kuyruğu birikiyordu. | Aynı pozisyona en fazla `ModifyMinIntervalMs` (1 sn) aralıkla SL değişikliği gönderilir. |
| Bağlantı yavaşken de yeni emir konuyordu. | Ping `MaxPingMs` (150 ms) üstündeyse yeni emir konmaz. Bu kontrol sadece canlı ve demo hesapta çalışır. |
| Gecikme ölçülmüyordu. | Ekranda ping ile ortalama ve en yüksek istek süresi gösterilir. `ASLAN EXEC SUMMARY` satırına da yazılır. |

Değişmeyen: SL, TP ve giriş emirleri zaten sunucuda bekler, gecikmeden etkilenmez.

Test için: `ASLAN_I_v275_gecikme_korumali.set`. Strategy Tester'da **Random delay** ile çalıştırın.

### v2.74: katmanlı koruma ve kayma koruması

Üç koruma katmanı aynı anda çalışır. Biri yetişemediğinde diğeri devreye girer:

| Katman | Nerede çalışır | Ne yapar |
|---|---|---|
| 1. SL | Sunucu | Her pozisyonun açılışta konan SL'si. EA donsa veya bağlantı kopsa da çalışır. |
| 2. Başa baş | EA → sunucu SL'si | Pozisyon 40 point kâra geçince SL, komisyon dahil başa başa çekilir. |
| 3. Basket trail | EA + sunucu yedeği | Toplam kâr zirvesinin bir kısmı korunur. EA sepeti kapatır. Ayrıca sepet tek yönlüyse korunan seviye **her pozisyonun SL'sine de yazılır**. Böylece EA'nın kapatması gecikir veya kayarsa sunucu SL'si devreye girer. |
| TP | Sunucu (limit) | Pozisyon başı 120 point TP. Limit emri olduğu için kâr çıkışında kayma olmaz. |

Kayma koruması:
- **Girişte Stop Limit:** Emir stop fiyatından ya da daha iyisinden dolar.
- **Kayma sigortası:** Son 20 girişin ortalama kayması 5 point'i aşarsa yeni emirler 30 dk durdurulur.
- **Önemli:** SL bir stop emridir ve hızlı piyasada kayabilir. Bunu tamamen önlemenin bir yolu yoktur. Etkisini azaltmanın tek yolu küçük lot kullanmak ve kârı TP ile (limit) almaktır.

Ayrıca orijinal koddaki `CommonStopForBasketNetLock` fonksiyonundaki ters ikili arama düzeltildi. Eski hali her zaman mevcut fiyata yapışık bir stop döndürüyordu.

v2.74 seti v2.75 ile değiştirildi.

### v2.73: işlem saatleri ve kâr koruma

Test A raporunun (v2.71) saat ve gün analizi:
- 7.463 işlemin **7.459'u sunucu saatiyle 01:00–06:00 arasında** (Asya / gece) açıldı ve zararın tamamı bu saatlerden geldi (−1.575 $).
- Sebep: Günlük −30 $ zarar sınırı, EA'yı her gün piyasanın en ince saatlerinde kilitliyordu. Londra ve New York seanslarında hiç işlem yapılmadı.
- Gün içi kâr 20 $'ı aşan 43 günün **23'ü zararla kapandı**.

| Ayar | Varsayılan | Açıklama |
|---|---|---|
| UseTradingHours / TradeStartHour / TradeEndHour | true / 10 / 19 | Sadece bu saatlerde (sunucu saati) emir konur. EC Markets yazın GMT+3 olduğu için 10–19, Londra seansına (07–16 GMT) denk gelir. |
| CloseOutsideHours | true | Saat dışına çıkıldığında açık pozisyonlar kapatılır. |
| UseDailyProfitLock / DailyLockStartMoney / DailyLockKeepPercent | true / 20 / 50 | Gün içi net kâr 20 $'ı geçtikten sonra zirvenin yarısı geri verilirse her şey kapatılır ve gün biter. |
| BasketLockPercent | 50 | Basket trail zirvenin en az %50'sini korur. Sabit 3 $ geri verme kuralı küçük zirvelerde aynen devam eder. |
| LegTakeProfitPoints | 0 | Her pozisyona TP (point). 0 = kapalı. Maliyetin 2 katından az olamaz. |
| LegBreakEvenPoints | 0 | Pozisyon bu kadar point kâra geçince SL, komisyon dahil başa başa çekilir. 0 = kapalı. |

**Dikkat:** v2.71 Londra ve NY saatlerinde neredeyse hiç işlem yapmadığı için bu saatlerdeki performansı **bilinmiyor**. Saat filtresi geceden gelen zararı keser, ama gündüz sonucunu ancak test gösterir.

v2.73 testleri (E, F, G) kullanıcının bildirdiğine göre ayrı ayrı zararla sonuçlandı.

### Karşılaştırma testleri
Hepsi aynı dönem (2026.05.01–2026.10.06), 10.000 $, gerçek tick verisi ve Random delay ile yapılmalı:

| Test | Ayar | Ne gösterir |
|---|---|---|
| A | v2.72 varsayılan | Stop Limit + maliyet bazlı mesafeler |
| B | v2.72, `GridSpreadMultiplier=0`, `SLSpreadMultiplier=0` | Stop Limit + orijinal 15/30 point mesafeler |
| C | v2.72, `UseStopLimit=false` | v2.70 ile aynı. Kıyas için −1.900 $ |
| D | Orijinal v2.63 | Değişikliklerin hiçbiri olmadan |

## Önerilen test sırası
1. **Strategy Tester:** Gerçek tick verisiyle test edin. "Executie" (gecikme) ayarını **Random delay** yapın. Komisyon, sunucunun sembol ayarlarından otomatik uygulanır. Haber filtresi tester'da çalışmaz.
2. **Demo + küçük canlı hesap, aynı anda:** Aynı ayarlarla, minimum lotla (0,01) birkaç hafta çalıştırın. Bu süre haber günlerini ve rollover saatlerini de kapsasın.
3. **Karşılaştırma:** İki hesabın `ASLAN_exec_<hesapNo>.csv` dosyalarını karşılaştırın: ortalama kayma, spread ve işlem başı net sonuç. Fark, demo sonuçlarının gerçek hesapta neden tutmadığını rakamla gösterir.
