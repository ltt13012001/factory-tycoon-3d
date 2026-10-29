# Bản di động (Android và iOS)

Từ bản 0.3, game chạy trên điện thoại và máy tính bảng, màn hình ngang.

## Điều khiển cảm ứng

| Thao tác | Cử chỉ |
|---|---|
| Di chuyển camera | Kéo một ngón |
| Phóng to, thu nhỏ | Chụm hoặc mở hai ngón |
| Xoay camera 90° | Xoay hai ngón, hoặc nút **< Xoay** / **Xoay >** góc dưới trái |
| Chọn máy hoặc công nhân, đặt máy | Chạm |
| Đóng bảng, hủy chế độ xây, bỏ chọn | Nút Quay lại của Android |
| Phóng to / thu nhỏ giao diện | Menu → A+ / A− |

Giao diện tự chọn cỡ chữ theo kích thước màn hình (to hơn trên điện thoại),
tránh tai thỏ và góc bo, rút gọn thanh thông tin trên màn hình hẹp. Game tự
lưu khi chuyển sang ứng dụng khác.

Trên máy tính có thể xem thử giao diện điện thoại:
`godot --path . --resolution 1200x540 -- --mobile --dpi=400`

## Đồ họa

Điện thoại dùng renderer **Mobile** (Vulkan, Metal trên iOS); máy không hỗ trợ
Vulkan tự chuyển sang OpenGL ES 3. Trên điện thoại tắt SSAO, bóng đổ dùng
bản đồ 2048 px và lọc mềm mức thấp để đỡ nóng máy và tốn pin. Máy tính vẫn
dùng Forward+ như cũ.

## Android

### Cài file APK có sẵn

1. Chép `FactoryTycoon3D-0.3-android.apk` vào điện thoại.
2. Mở file, cho phép "Cài ứng dụng không rõ nguồn gốc" khi được hỏi.
3. Cần Android 7.0 trở lên, chip ARM 32 hoặc 64 bit (gần như mọi điện thoại).

### Tự xuất APK từ mã nguồn

Cần Godot 4.7.2, export templates 4.7.2, JDK 17 và Android SDK (build-tools
có `apksigner`, platform-tools). Trong Godot: Editor Settings → Export →
Android, điền đường dẫn Android SDK và JDK. Sau đó:

```bash
# Ký bằng khóa release (đừng đưa khóa và mật khẩu vào git)
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/duong/dan/factorytycoon3d-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=factorytycoon3d
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...
godot --headless --path . --export-release "Android" build/android/FactoryTycoon3D.apk
```

Bản cập nhật phải ký bằng **cùng một khóa**, nếu không điện thoại sẽ không
cho cài đè. Muốn lên Google Play thì bật `gradle_build/use_gradle_build` và
`gradle_build/export_format` = AAB trong preset, rồi tải file .aab lên Play
Console (cần tài khoản nhà phát triển Google Play, phí một lần 25 USD).

## iOS

Apple chỉ cho build và ký ứng dụng iOS trên **máy Mac có Xcode**. Preset
"iOS" đã có sẵn (mã gói `com.ltt13012001.factorytycoon3d`, iOS 14 trở lên,
iPhone và iPad, màn hình ngang).

### Cách 1: mở project Xcode đã xuất sẵn

1. Trên Mac, cài Xcode (App Store), giải nén `FactoryTycoon3D-0.3-ios-xcode.zip`.
2. Mở `FactoryTycoon3D.xcodeproj`.
3. Chọn target FactoryTycoon3D → **Signing & Capabilities** → **Team**:
   chọn Apple ID của bạn (Xcode → Settings → Accounts để thêm). Nếu Xcode báo
   trùng mã gói, đổi Bundle Identifier thành tên khác, ví dụ
   `com.tien.factorytycoon3d`.
4. Cắm iPhone, trên iPhone bật Cài đặt → Quyền riêng tư & Bảo mật →
   **Chế độ nhà phát triển**.
5. Chọn iPhone ở thanh trên của Xcode rồi bấm Run (▶). Lần đầu, trên iPhone
   vào Cài đặt → Cài đặt chung → Quản lý VPN & Thiết bị để tin cậy nhà phát
   triển.

Với Apple ID miễn phí, ứng dụng chạy được 7 ngày rồi phải cài lại từ Xcode.
Tài khoản Apple Developer Program (99 USD/năm) bỏ giới hạn này và cho phép
gửi bản thử qua TestFlight hoặc đưa lên App Store (Product → Archive).

### Cách 2: xuất từ Godot trên Mac

1. Cài Godot 4.7.2 và export templates trên Mac, mở thư mục dự án.
2. Project → Export → iOS: điền **App Store Team ID** (10 ký tự, xem ở
   developer.apple.com → Membership, hoặc trong Xcode).
3. Bấm Export Project, chọn file `.ipa`. Godot gọi Xcode để build và ký.
