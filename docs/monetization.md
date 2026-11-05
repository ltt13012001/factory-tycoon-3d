# Kim cương, quảng cáo và nạp tiền (bản 0.11)

Tài liệu này giải thích cách game kiếm tiền và **những việc bạn phải tự làm**
(tài khoản AdMob, sản phẩm trên App Store Connect / Google Play, plugin) trước
khi bản phát hành hiện quảng cáo thật và nhận tiền thật.

## 1. Cách sắp xếp quảng cáo

Game **chỉ dùng quảng cáo có thưởng (rewarded), người chơi tự bấm mới xem**.
Không có quảng cáo bật ngang giữa lúc chơi (interstitial), không có banner.

Lý do: game quản lý chạy lâu, người chơi mở lại nhiều lần mỗi ngày. Quảng cáo
ép buộc làm người chơi bỏ game và bị chấm điểm thấp; quảng cáo có thưởng trả
tiền cao nhất trên mỗi lượt xem (eCPM) và người chơi xem vì muốn phần thưởng.
Apple và Google đều cho phép kiểu này, miễn là phần thưởng ghi rõ trước khi xem.

| Chỗ đặt | Thưởng | Giới hạn |
|---|---|---|
| Bảng Kim cương → "Xem quảng cáo: +5 kim cương" | 5 kim cương | 5 lần / ngày thật |
| Báo cáo cuối ngày → "Xem quảng cáo: thưởng thêm $…" | 20% doanh thu ngày đó (ít nhất $200) | 1 lần mỗi báo cáo |
| Bảng Kim cương → Tăng tốc sản xuất → "Xem QC" | Máy chạy nhanh hơn 50% trong 2 giờ game | chung giới hạn ngày |

- Tổng cộng tối đa **12 quảng cáo mỗi ngày thật**, cách nhau ít nhất 20 giây.
- Game tự tạm dừng khi quảng cáo chạy, chạy lại khi đóng.
- Đóng quảng cáo trước khi xong thì không có thưởng (mạng quảng cáo quyết định).
- Bản web và bản Windows không có quảng cáo; các nút này tự ẩn.

## 2. Kim cương

Kim cương là tiền tệ cao cấp. Game mới bắt đầu với 30 kim cương; người chơi
cũ cập nhật lên 0.11 cũng được tặng 30. Bấm vào ô kim cương trên thanh trên
cùng để mở bảng Kim cương.

**Cách nhận**

| Nguồn | Số kim cương |
|---|---|
| 3 nhiệm vụ mỗi ngày game (sản xuất, giao đơn, doanh thu, mua nguyên liệu…), mục tiêu tăng theo quy mô xưởng | 1–3 mỗi nhiệm vụ, +3 khi xong cả 3 |
| 14 thành tựu một lần (đơn đầu tiên, 25/100 đơn, xưởng thứ 2, các cấp công ty, doanh thu…) | 10–120 mỗi thành tựu, tổng 535 |
| Xem quảng cáo | 5 mỗi lần, 25 mỗi ngày |
| Nạp tiền | 60 / 330 / 750 / 1.700 |

**Cách dùng**

| Việc | Giá |
|---|---|
| **Quản lý cấp cao** (7 người, mỗi người 3 cấp, làm việc mãi mãi, không lương) | 60–750 mỗi cấp |
| Tăng tốc sản xuất +50% trong 4 giờ game | 10 |
| Hoàn thành ngay công trình, khảo sát hoặc xây xưởng/chi nhánh | 1 kim cương / 3 giờ còn lại |
| Sửa máy ngay (bấm vào máy) | 3 |
| Liên hoan nhân viên: tâm trạng +25, chấm dứt đình công | 20 |
| Đổi 10 kim cương lấy tiền mặt ($1.000 → $100.000 theo cấp công ty) | 10 |

Quản lý cấp cao:

| Vị trí | Mỗi cấp |
|---|---|
| Chuyên gia năng suất | máy ở mọi xưởng nhanh hơn 8% |
| Kỹ sư trưởng | máy hao mòn chậm hơn 20% |
| Trưởng phòng thu mua | hạt nhựa rẻ hơn 8% |
| Chuyên gia đàm phán | đơn hàng mới trả giá cao hơn 6% |
| Chuyên gia gắn kết nhân viên | tâm trạng +6 |
| Giám đốc kho vận | kho rộng thêm 15% |
| Cố vấn chiến lược | chi nhánh lãi thêm 10% |

Kim cương và quản lý cấp cao **được giữ lại khi chơi lại từ đầu**, để người đã
nạp tiền không mất gì. Tất cả số liệu nằm trong `core/diamond_manager.gd` và
`core/quest_manager.gd`, sửa ở đó để cân bằng lại.

## 3. Gói nạp (mua trong ứng dụng)

Bốn gói, đều là loại **Consumable** (tiêu hao, mua nhiều lần được):

| Product ID | Kim cương | Giá gợi ý (Apple tier) |
|---|---|---|
| `com.ltt13012001.factorytycoon3d.diamonds_small` | 60 | 0,99 USD (≈ 26.000 ₫) |
| `com.ltt13012001.factorytycoon3d.diamonds_medium` | 300 + 30 | 4,99 USD (≈ 129.000 ₫) |
| `com.ltt13012001.factorytycoon3d.diamonds_large` | 650 + 100 | 9,99 USD (≈ 259.000 ₫) |
| `com.ltt13012001.factorytycoon3d.diamonds_huge` | 1.400 + 300 | 19,99 USD (≈ 499.000 ₫) |

Giá hiển thị trong game lấy từ App Store / Google Play theo tiền tệ của người
chơi; giá USD ở bảng chỉ để hiện khi chưa tải được giá. Nếu đổi Bundle ID thì
sửa `PRODUCT_PREFIX` trong `scripts/monetization/monetization_config.gd`.

Trên iOS, mọi giao dịch mua kim cương **bắt buộc** đi qua Apple In-App Purchase
(Apple thu 15% nếu bạn đăng ký Small Business Program, 30% nếu không). Game
không có link hay nút thanh toán nào khác.

Kim cương được cộng và **lưu game xong mới báo cho cửa hàng là đã giao hàng**,
nên nếu game tắt giữa chừng thì lần mở sau cửa hàng gửi lại giao dịch và game
cộng đúng một lần (chống cộng trùng theo mã giao dịch).

## 4. Việc bạn cần làm

### 4.1. AdMob (quảng cáo)

1. Tạo tài khoản ở https://admob.google.com bằng Gmail, điền thông tin thanh
   toán (Payments) và thuế. Google trả tiền khi số dư đạt 100 USD.
2. **Apps → Add app**: thêm app iOS (và Android nếu phát hành Android). Nếu
   app chưa lên store, chọn "No" khi được hỏi đã phát hành chưa, sau này liên
   kết lại.
3. Mỗi app: **Ad units → Add ad unit → Rewarded**. Đặt tên ví dụ
   `kim_cuong_rewarded`, phần thưởng ghi `5 kim cương` (game tự quyết thưởng,
   số này chỉ để báo cáo).
4. Ghi lại **App ID** (`ca-app-pub-xxx~yyy`) và **Ad unit ID**
   (`ca-app-pub-xxx/zzz`) của từng nền tảng.
5. Mở `scripts/monetization/monetization_config.gd`, thay
   `ADMOB_REWARDED_IOS` và `ADMOB_REWARDED_ANDROID` bằng Ad unit ID của bạn.
   Hiện đang để mã quảng cáo thử của Google (hiện được, không trả tiền). Chỉ
   thay khi phát hành; khi tự thử trên máy, giữ mã thử hoặc thêm máy của bạn
   làm test device trong AdMob, **không bấm vào quảng cáo thật của chính mình**
   (Google có thể khóa tài khoản).
6. Cài plugin **Godot AdMob** (Poing Studios) cho Godot 4:
   - Trong Godot: AssetLib → tìm "AdMob" → cài vào `addons/admob`, bật ở
     Project → Project Settings → Plugins.
   - Tải phần native cho Android và iOS theo hướng dẫn của plugin
     (https://github.com/poingstudios/godot-admob-plugin), chọn bản khớp
     Godot 4.7. iOS: chép vào `ios/plugins/`; Android: dùng Gradle build.
   - Điền **App ID** vào cài đặt của plugin (Android) và vào Info.plist khóa
     `GADApplicationIdentifier` (iOS, trong Project → Export → iOS → plugin
     hoặc thêm trong Xcode). Thêm danh sách `SKAdNetworkItems` của Google vào
     Info.plist (plugin có sẵn danh sách).
   - Bật plugin trong cấu hình xuất: Project → Export → iOS/Android → Plugins.
   Game tự nhận ra plugin khi chạy; không cần sửa code.
7. Tạo file `app-ads.txt` trên một trang web của bạn (ví dụ GitHub Pages) và
   điền trang đó vào mục Marketing/Support URL của app, theo hướng dẫn trong
   AdMob → Apps → app-ads.txt. Không bắt buộc nhưng thiếu thì quảng cáo trả ít
   hơn.

**Không cần ATT (hộp thoại "cho phép theo dõi")**: game xin quảng cáo không
cá nhân hoá (`NON_PERSONALIZED_ADS = true`), không đọc mã quảng cáo IDFA, nên
không phải hỏi người chơi. Đổi lại quảng cáo trả thấp hơn một chút. Nếu muốn
quảng cáo cá nhân hoá sau này: thêm hộp thoại ATT (plugin có hỗ trợ), khóa
`NSUserTrackingUsageDescription` trong Info.plist, đặt cờ thành `false`, và
khai "Used for Tracking" trong App Privacy.

**Người chơi ở châu Âu (EEA, Anh, Thụy Sĩ)**: Google yêu cầu hiện bảng xin
đồng ý (UMP, cấu hình ở AdMob → Privacy & messaging). Nếu chưa làm, đơn giản
nhất là không phát hành ở các nước này, hoặc bật thông báo GDPR trong AdMob và
gọi UMP của plugin trước khi tải quảng cáo.

### 4.2. App Store Connect (nạp tiền trên iPhone/iPad)

1. **Business → Agreements**: ký **Paid Apps Agreement**, điền tài khoản ngân
   hàng và thuế (form W-8BEN cho cá nhân ở Việt Nam). Chưa xong bước này thì
   không bán được gì, kể cả khi đã tạo sản phẩm.
2. (Nên làm) Đăng ký **App Store Small Business Program** để Apple chỉ thu 15%.
3. Vào app → **Monetization → In-App Purchases → +**, chọn **Consumable**, tạo
   4 sản phẩm với đúng Product ID ở mục 3. Mỗi sản phẩm:
   - Reference Name: ví dụ `60 kim cương`.
   - Price: chọn mức giá (bảng ở mục 3).
   - Localization (Vietnamese): Display Name `60 Kim cương`, Description
     `Kim cương để chiêu mộ quản lý cấp cao và tăng tốc nhà máy`.
   - Review Information: ảnh chụp bảng Kim cương (ví dụ
     `41_diamonds_shop.png`), ghi chú `Opens from the diamond button in the top bar.`
4. Lần đầu: ở trang phiên bản app, mục **In-App Purchases and Subscriptions**,
   chọn cả 4 gói để gửi duyệt **cùng** bản build. Apple chỉ duyệt sản phẩm đầu
   tiên khi đi kèm một phiên bản app.
5. Plugin mua hàng: tải **InAppStore** từ
   https://github.com/godot-sdk-integrations/godot-ios-plugins (bản khớp
   Godot 4.7, hoặc tự build theo README), chép `inappstore.gdip` và thư mục
   thư viện vào `ios/plugins/`, rồi bật **Plugins → In App Store** trong
   Project → Export → iOS.
6. Trong Xcode: target → **Signing & Capabilities → + Capability → In-App
   Purchase**.
7. Thử trước khi gửi: App Store Connect → Users and Access → **Sandbox
   Testers** → tạo tài khoản thử, đăng nhập trên iPhone ở Settings → App
   Store → Sandbox Account, rồi mua trong bản chạy từ Xcode hoặc TestFlight
   (không mất tiền).

### 4.3. Google Play (nếu phát hành Android)

1. Play Console → **Setup → Payments profile**: tạo hồ sơ thanh toán.
2. App → **Monetize → Products → In-app products**: tạo 4 sản phẩm cùng
   Product ID, bật Active. (Cần tải lên một bản có quyền BILLING trước, plugin
   tự thêm quyền này.)
3. Cài plugin **GodotGooglePlayBilling**
   (https://github.com/godot-sdk-integrations/godot-google-play-billing),
   bật trong Project → Export → Android → Plugins, dùng Gradle build.
4. Thêm tài khoản thử ở **Setup → License testing** để mua thử miễn phí.

### 4.4. Quyền riêng tư và thông tin app

- `docs/privacy-policy.md` đã cập nhật (có quảng cáo AdMob và mua trong ứng
  dụng). Link chính sách phải mở được khi gửi duyệt.
- **App Privacy** (App Store Connect) không còn chọn "No data collected" được.
  Theo hướng dẫn của Google cho AdMob, khai các loại dữ liệu sau, mục đích
  "Third-Party Advertising" và "Analytics", **không** liên kết với danh tính,
  **không** dùng để theo dõi (vì quảng cáo không cá nhân hoá, không ATT):
  - Identifiers → Device ID
  - Usage Data → Product Interaction, Advertising Data
  - Diagnostics → Crash Data, Performance Data
  - Location → Coarse Location
  Mua trong ứng dụng do Apple xử lý, game không lưu thông tin thanh toán.
- Google Play → **Data safety**: khai tương tự; mục **Ads**: "Yes, contains ads".
- Mô tả app: thay câu "không quảng cáo, không thu thập dữ liệu" (đã sửa trong
  `docs/ios-app-store.md`).
- Age Rating: trả lời có **mua trong ứng dụng** và có **quảng cáo**; vẫn 4+
  (hoặc 9+ tuỳ bảng câu hỏi mới của Apple). Đánh dấu app không dành cho trẻ
  em (không chọn Kids Category), vì quảng cáo cho trẻ em có luật riêng.
- Ghi chú cho người duyệt (App Review Information):
  `Single-player factory game. Optional rewarded ads (player taps "Xem quảng cáo"). Diamonds are sold as consumable in-app purchases via Apple IAP in the Kim cương (diamond) panel, opened from the diamond button in the top bar. No login. UI is in Vietnamese.`

### 4.5. Lưu ý tại Việt Nam

Game có nạp tiền phát hành cho người chơi ở Việt Nam thuộc diện trò chơi điện
tử trên mạng, cần giấy phép và quyết định phê duyệt nội dung theo quy định
hiện hành (Nghị định 147/2024/NĐ-CP). Apple và Google có thể gỡ game có thanh
toán tại Việt Nam nếu thiếu giấy phép. Nên tìm hiểu kỹ trước khi mở bán ở khu
vực Việt Nam, hoặc tạm thời phát hành ở các nước khác.

## 5. Thử trên máy tính

Khi chạy từ Godot (bản debug), game dùng **quảng cáo thử** (màn hình đếm 5
giây) và **cửa hàng thử** (bấm mua là hỏi xác nhận rồi cộng kim cương, không
trừ tiền). Bản phát hành (release) không có hai thứ này; nếu chưa cài plugin
thì nút quảng cáo ẩn và bảng nạp ghi "chỉ có trên bản iPhone, iPad và
Android".

- Bật bản thử trong bản release: `-- --demo-monetization`.
- Tắt hẳn khi chạy debug: `-- --no-monetization`.
- Ảnh chụp các bảng mới: `godot --path . -- --screenshot=/tmp/shots --screenshot-diamonds`.

## 6. Mã nguồn

| File | Vai trò |
|---|---|
| `core/diamond_manager.gd` | Số dư, quản lý cấp cao, tăng tốc, liên hoan, sửa ngay, hoàn thành ngay, đổi tiền, giới hạn quảng cáo, cộng gói nạp |
| `core/quest_manager.gd` | Nhiệm vụ ngày và thành tựu |
| `autoload/monetization.gd` | Chọn mạng quảng cáo / cửa hàng theo nền tảng, chạy quảng cáo, nhận kết quả mua |
| `scripts/monetization/` | `admob_ads.gd`, `apple_store.gd`, `google_play_store.gd`, bản thử, cấu hình |
| `scripts/ui/diamond_panel.gd`, `quests_panel.gd` | Hai bảng mới |
