# Đưa Factory Tycoon 3D lên App Store

Hướng dẫn từng bước cho bản 0.10. Phần chuẩn bị trong dự án đã xong (cấu hình
xuất iOS, icon, màn hình khởi động, khai báo quyền riêng tư, ảnh chụp màn
hình). Những bước còn lại cần **máy Mac có Xcode** và **tài khoản Apple
Developer**, vì Apple chỉ cho ký và tải ứng dụng lên từ đó.

## Đã chuẩn bị sẵn trong dự án

| Mục | Giá trị |
|---|---|
| Tên hiển thị | Factory Tycoon 3D |
| Mã gói (Bundle ID) | `com.ltt13012001.factorytycoon3d` |
| Phiên bản / số build | 0.10.0 / 10 |
| Thiết bị | iPhone và iPad, iOS 14 trở lên, chỉ màn hình ngang |
| Icon | `assets/icon.png` 1024×1024, không có nền trong suốt (đúng yêu cầu Apple) |
| Màn hình khởi động | Nền xanh đậm của game |
| Mã hóa (Export Compliance) | `ITSAppUsesNonExemptEncryption = NO`, không phải khai báo thêm |
| Privacy manifest | `PrivacyInfo.xcprivacy` do Godot tạo, không theo dõi người dùng |
| Ký app | Tự động (Automatic), chỉ cần chọn Team trong Xcode |
| Chính sách quyền riêng tư | `docs/privacy-policy.md` |

Game không dùng mạng, quảng cáo, tài khoản, camera hay vị trí, nên phần khai
báo với Apple rất đơn giản.

## Bước 1: Đăng ký Apple Developer Program (một lần)

1. Vào https://developer.apple.com/programs/enroll/ và đăng nhập bằng Apple ID
   (Apple ID phải bật xác thực hai lớp).
2. Chọn đăng ký **cá nhân (Individual)**. Tên người bán trên App Store sẽ là họ
   tên thật của bạn. Muốn hiện tên công ty thì phải đăng ký dạng tổ chức, cần
   số D-U-N-S của công ty.
3. Trả phí **99 USD/năm**. Apple duyệt thường trong 1–2 ngày.
4. Sau khi được duyệt, vào https://developer.apple.com/account → Membership
   details, ghi lại **Team ID** (10 ký tự).
5. Vào https://appstoreconnect.apple.com → Business (Agreements): chấp nhận
   thỏa thuận. Game miễn phí chỉ cần thỏa thuận Free Apps. Nếu sau này bán có
   phí thì điền thêm thông tin ngân hàng và thuế.

## Bước 2: Chuẩn bị máy Mac

1. Cài **Xcode** bản mới nhất từ Mac App Store. Apple chỉ nhận ứng dụng build
   bằng Xcode và iOS SDK mới.
2. Mở Xcode → Settings → Accounts → **+** → Apple ID, đăng nhập tài khoản
   Developer.

## Bước 3: Mở project và ký app

1. Giải nén `FactoryTycoon3D-0.10-ios-xcode.zip`, mở `FactoryTycoon3D.xcodeproj`.
2. Bấm vào project **FactoryTycoon3D** ở cột trái → target **FactoryTycoon3D** →
   tab **Signing & Capabilities**.
3. Để **Automatically manage signing** được bật, chọn **Team** là tài khoản
   của bạn. Xcode tự tạo Bundle ID và chứng chỉ.
   - Nếu Xcode báo mã gói đã có người dùng, đổi **Bundle Identifier** thành tên
     khác, ví dụ `com.tien.factorytycoon3d`, và dùng đúng mã đó ở bước 4.
4. (Nên làm) Cắm iPhone, chọn iPhone ở thanh trên, bấm **Run ▶** để chơi thử
   trên máy thật trước khi gửi.

Nếu xuất trực tiếp từ Godot trên Mac thay vì dùng file zip: Project → Export →
iOS, điền **App Store Team ID**, bấm Export Project. Mỗi lần ra bản mới, tăng
**Version** (số build) lên 1, ví dụ 11, 12…

## Bước 4: Tạo ứng dụng trên App Store Connect

1. https://appstoreconnect.apple.com → **Apps** → **+** → **New App**.
2. Điền:
   - Platforms: **iOS**
   - Name: tên trên App Store, tối đa 30 ký tự, không được trùng app khác.
     Gợi ý: `Factory Tycoon 3D` hoặc `Quản Lý Nhà Máy 3D`.
   - Primary Language: **Vietnamese**
   - Bundle ID: chọn `com.ltt13012001.factorytycoon3d` (hoặc mã bạn đổi ở bước 3)
   - SKU: mã riêng tùy ý, ví dụ `factorytycoon3d`
   - User Access: Full Access

## Bước 5: Tải bản build lên

1. Trong Xcode, ở thanh trên chọn thiết bị **Any iOS Device (arm64)**.
2. Menu **Product → Archive**. Đợi vài phút.
3. Cửa sổ Organizer mở ra: chọn bản vừa tạo → **Distribute App** →
   **App Store Connect** → **Upload**, cứ để mặc định và bấm Next tới hết.
4. Sau 10–30 phút, bản build hiện trong App Store Connect → tab
   **TestFlight**. Có thể mời mình hoặc bạn bè chơi thử qua app TestFlight
   trước khi phát hành.

## Bước 6: Điền thông tin trang App Store

Trong app → phiên bản **1.0 Prepare for Submission** (có thể đổi số hiển thị
thành 0.10.0 cho khớp, hoặc dùng 1.0 cho lần ra mắt; khi đó sửa
`application/short_version` trong `export_presets.cfg` cho giống và build lại).

**Ảnh chụp màn hình** (đã có sẵn trong thư mục `app-store-screenshots-0.10`):
- iPhone 6.9": ảnh 2868×1320, chọn 3–10 ảnh từ thư mục `iphone-6.9`.
- iPad 13": ảnh 2752×2064, chọn 3–10 ảnh từ thư mục `ipad-13`.

**Nội dung gợi ý** (sửa tùy ý):

- Subtitle (≤30 ký tự): `Xây và quản lý nhà máy 3D`
- Promotional Text: `Bản 0.10: ghé thăm chi nhánh Hạ Long, lưu game an toàn hơn, đồ họa đẹp hơn.`
- Keywords (≤100 ký tự, cách nhau dấu phẩy):
  `nhà máy,quản lý,tycoon,xây dựng,idle,kinh doanh,công nhân,sản xuất,mô phỏng,factory`
- Description:

  > Bạn là giám đốc một nhà máy nhỏ ở Việt Nam. Nhận đơn hàng, mua nguyên liệu,
  > đặt máy móc, tuyển công nhân và sắp xếp ca làm để giao hàng đúng hạn.
  >
  > - Nhà máy 3D sống động: công nhân đi lại, nghỉ ngơi, trò chuyện, tan ca về nhà.
  > - Quản lý nhân sự: lương, ca làm, tăng ca, tâm trạng, và cả đình công nếu bạn ép quá.
  > - Mở rộng: tăng tốc dây chuyền, xây thêm nhà máy bên cạnh, mở chi nhánh từ
  >   Bình Dương, Hải Phòng, Đà Nẵng, Hạ Long tới nước ngoài.
  > - Chơi hoàn toàn offline, không quảng cáo, không thu thập dữ liệu.
  > - Điều khiển cảm ứng: kéo, chụm để phóng to, xoay hai ngón.

- Support URL: `https://github.com/ltt13012001/factory-tycoon-3d/issues`
- Privacy Policy URL (trong App Information):
  `https://github.com/ltt13012001/factory-tycoon-3d/blob/main/docs/privacy-policy.md`
  (link này chạy sau khi gộp PR vào nhánh main).
- Copyright: `2026 <họ tên của bạn>`
- Category (App Information): Primary **Games**, sub-category **Simulation**;
  Secondary **Strategy** (tùy chọn).
- Price and Availability: **Free**, chọn các quốc gia muốn phát hành.

**App Privacy** → Get Started → "Do you or your third-party partners collect
data from this app?" → **No, we do not collect data from this app** → Publish.

**Age Rating**: trả lời bảng câu hỏi, game không có bạo lực, cờ bạc, nội dung
người lớn hay chat với người lạ, nên chọn "None"/"No" hết. Kết quả dự kiến 4+.

**App Review Information**: điền họ tên, số điện thoại, email. Không cần tài
khoản demo. Ghi chú gợi ý:
`Offline single-player factory management game. No login, no network, no in-app purchases. UI is in Vietnamese.`

## Bước 7: Gửi duyệt

1. Ở mục **Build** của phiên bản, bấm **+** chọn build vừa tải lên.
2. Kiểm tra Export Compliance: nếu được hỏi, chọn **None of the algorithms
   mentioned above** (game không dùng mã hóa riêng).
3. Chọn cách phát hành: tự động sau khi duyệt, hoặc tự bấm phát hành.
4. Bấm **Add for Review** → **Submit to App Review**.

Apple thường duyệt trong 1–3 ngày. Nếu bị từ chối, Apple ghi lý do trong
App Store Connect (mục Resolution Center); gửi lại lý do đó để sửa.

## Lưu ý

- **Liên minh châu Âu**: Apple yêu cầu khai báo "trader status" (Digital
  Services Act) mới phát hành được ở EU. Cá nhân không kinh doanh có thể khai
  không phải trader; nếu không muốn khai, bỏ chọn các nước EU ở Availability.
- **Phát hành tại Việt Nam**: trò chơi điện tử tại Việt Nam có quy định riêng
  về cấp phép. Game offline (không chơi qua mạng) thường đơn giản hơn, nhưng
  nên kiểm tra quy định hiện hành trước khi mở cho khu vực Việt Nam.
- Mỗi bản cập nhật sau: tăng `application/version` (số build) trong
  `export_presets.cfg`, đổi `application/short_version` nếu đổi phiên bản, xuất
  lại, Archive và Upload như bước 5, rồi tạo phiên bản mới trong App Store
  Connect.
