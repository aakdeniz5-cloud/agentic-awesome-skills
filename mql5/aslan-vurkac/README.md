# ASLAN Vur-Kaç M5 v2.70 LIVE

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

## Önerilen test sırası
1. **Strategy Tester:** Gerçek tick verisiyle test edin. "Executie" (gecikme) ayarını **Random delay** yapın. Komisyon, sunucunun sembol ayarlarından otomatik uygulanır. Haber filtresi tester'da çalışmaz.
2. **Demo + küçük canlı hesap, aynı anda:** Aynı ayarlarla, minimum lotla (0,01) birkaç hafta çalıştırın. Bu süre haber günlerini ve rollover saatlerini de kapsasın.
3. **Karşılaştırma:** İki hesabın `ASLAN_exec_<hesapNo>.csv` dosyalarını karşılaştırın: ortalama kayma, spread ve işlem başı net sonuç. Fark, demo sonuçlarının gerçek hesapta neden tutmadığını rakamla gösterir.
