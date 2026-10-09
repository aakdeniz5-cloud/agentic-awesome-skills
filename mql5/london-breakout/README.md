# LondonBreakoutEA (XAUUSD M5)

Kullanıcının gönderdiği EC Markets XAUUSD.n M5 verisi (2025.05.13 – 2026.10.09, ~100.000 mum) üzerinde yapılan araştırmadan çıkan, kuralları sabit ve sade bir EA.

> Bu sonuçlar mum verisiyle yapılmış bir simülasyondan geliyor. Gerçek para kullanmadan önce MT5 Strategy Tester'da gerçek tick verisiyle doğrulanmalı, ardından demo ve küçük bir canlı hesapta denenmelidir. Kâr garantisi yoktur.

## Kurallar (sunucu saati)
1. **Asya aralığı:** 01:00–10:00 arası M5 mumlarının en yüksek ve en düşük seviyesi.
2. **10:00 (Londra açılışı):** Aralığın 5 point üstüne Buy Stop, 5 point altına Sell Stop konur. Biri dolunca diğeri silinir.
3. **SL ve TP:** SL = 3 × ATR(14, M5), TP = 2 × SL. Günde en fazla 1 işlem.
4. **Zaman sınırları:** 14:00'a kadar dolmayan emirler silinir. Açık pozisyon 19:00'da kapatılır.
5. **Lot:** Bakiyenin %0,5'i riske edilir. Hesaplanan lot min lottan küçükse o gün işlem yapılmaz.

Grid, martingale ve ortalama maliyet yok. Her işlemin SL'si ve TP'si var.

## Araştırma yöntemi
- **Maliyet:** İşlem başına 26 point (spread 15 + komisyon 6 + kayma 5). Kontrol için 40 point ile de test edildi.
- **Dönem ayrımı:** Optimizasyon dönemi 2025.05 – 2026.01, doğrulama dönemi 2026.02 – 2026.10. Doğrulama dönemine optimizasyon sırasında hiç bakılmadı.
- **Simülasyon kuralı:** Aynı mumda hem SL hem TP görülürse önce SL'nin dolduğu varsayıldı (kötümser).
- Test edilen bütün fikirlerin sonuçları aşağıda, sadece en iyisininki değil.

| Fikir | Optimizasyon dönemi | Doğrulama dönemi | Karar |
|---|---|---|---|
| NY açılış kırılımı (12 ayar) | Çoğu kârlı | **12 ayarın 12'si zararda** | Reddedildi (overfitting) |
| Londra açılış kırılımı (12 ayar) | Karışık | **12 ayarın 11'i kârlı** | İncelendi |

Seçilen ayar (SL 3×ATR, TP 2R):

| | İşlem | Ortalama R | Profit factor | Kazanma oranı |
|---|---|---|---|---|
| Optimizasyon | 113 | +0,18 | 1,73 | %42 |
| Doğrulama | 106 | +0,23 | 1,31 | %43 |
| Toplam | 219 | +0,21 (t = 2,1) | | |

Sağlamlık kontrolleri:
- **Maliyet 26 → 40 point:** Sonuç neredeyse değişmiyor. Ortalama SL yaklaşık 12–13 $ olduğu için maliyet riskin %2'si kadar.
- **Komşu ayarlar:** Tampon 0 veya 15 point, işlem penceresi 12:00 veya 16:00'ya kadar, çıkış 17:00 veya 21:00, SL 3,75×ATR. Hepsinde iki dönem de pozitif. Sadece SL 2,25×ATR doğrulama döneminde ≈0.
- **Çeyrekler:** 6 çeyreğin 5'i pozitif (2026Q1 negatif).
- **Bootstrap:** Ortalamanın ≤ 0 olma olasılığı yaklaşık %1,5.
- **%0,5 riskle:** 10.000 $ → yaklaşık 12.470 $ (17 ay), en büyük düşüş yaklaşık %7,3, en uzun kayıp serisi 9 işlem.
- **Dikkat:** Kazancın neredeyse tamamı satış işlemlerinden geliyor (iki dönemde de satış ≈ +0,4R, alış ≈ 0R). Yine de bu veriye bakarak alışları kapatmak ayrı bir overfitting olur; varsayılan olarak iki yön de açık.

Araştırma script'leri `research/` klasöründe. Mum verisi kullanıcıya ait olduğu için depoya eklenmedi.

## MT5 gerçek tick doğrulaması (kullanıcı testi)
EC Markets XAUUSD.n, M5, 2026.02.01–2026.10.06, 10.000 $, %100 gerçek tick:

| | Simülasyon (doğrulama dönemi) | MT5 gerçek tick |
|---|---|---|
| İşlem | 106 | 101 |
| Kazanma oranı | %42,5 | %41,6 |
| Ortalama R (fiyat) | +0,23 (maliyet sonrası) | +0,20 (brüt) |
| Profit factor | 1,31 | 1,26 |
| Net | — | **+686 $ (+%6,9)** |
| En büyük düşüş | — | %5,2 |

- **Aylık sonuç:** Şubat −92 $, Mart −131 $, Nisan −1 $, Mayıs +156 $, Haziran +198 $, Temmuz +252 $, Ağustos +116 $, Eylül +239 $, Ekim (6 gün) −51 $.
- **Stop emri kayması:** Ortalama 31 point, medyan 11 point. Simülasyonda 5 point varsayılmıştı, ama SL ~1.200 point olduğu için bu fark riskin yaklaşık %2,5'i kadar.
- **Yön farkı:** Kazanma oranı satışta %51, alışta %31. Araştırmadaki yön farkıyla tutarlı.
- **Risk:** Lot adımı aşağı yuvarlandığı için gerçekleşen risk %0,5'in biraz altında kalıyor.

## Kurulum ve doğrulama
1. `LondonBreakoutEA.mq5` dosyasını `MQL5\Experts` klasörüne kopyalayın ve F7 ile derleyin.
2. `sets/LondonBreakout_varsayilan.set` dosyasını `MQL5\Profiles\Tester` klasörüne kopyalayın.
3. Strategy Tester ayarları:
   - XAUUSD.n, **M5**
   - **Elke tick op basis van echte ticks**
   - 10.000 $
   - Önce **2026.02.01 – 2026.10.06**, sonra mümkünse geçmiş verinin izin verdiği en uzun dönem
4. Tester sonucu yukarıdaki doğrulama rakamlarına yakınsa (pozitif, PF > 1,2), demoda ve ardından küçük canlı hesapta, en az 1–2 ay %0,25–0,5 riskle deneyin.

## Ayarlar
| Ayar | Varsayılan | Açıklama |
|---|---|---|
| InpRiskPercent | 0.5 | İşlem başı risk (% bakiye) |
| InpFixedLot | 0 | > 0 ise sabit lot |
| InpRangeStartHour / InpRangeEndHour | 1 / 10 | Asya aralığı (sunucu saati) |
| InpTradeEndHour | 14 | Dolmayan emirlerin silinme saati |
| InpExitHour | 19 | Açık pozisyonun kapatılma saati |
| InpBufferPoints | 5 | Aralık dışına tampon |
| InpSLATRMult / InpTPRR | 3.0 / 2.0 | SL = ATR(14, M5) × 3, TP = 2R |
| InpAllowBuy / InpAllowSell | true / true | Yön izinleri |
| InpMaxSpreadPoints | 40 | Emir koyarken en yüksek spread |
| InpSkipFriday | false | Cuma işlem yapma |
