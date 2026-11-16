# Đưa game lên App Store khi không có máy Mac

Apple chỉ cho build app iOS bằng Xcode trên macOS, nhưng máy Mac đó không cần
là của bạn. Dự án đã có sẵn workflow `.github/workflows/ios-testflight.yml`:
GitHub mượn một máy Mac trên đám mây, xuất game từ Godot, ký app và tải thẳng
lên App Store Connect (TestFlight). Repo đang để công khai nên máy Mac của
GitHub Actions **miễn phí**.

Mọi việc còn lại làm trên trình duyệt, máy Windows hay điện thoại đều được.
Vẫn cần **tài khoản Apple Developer (99 USD/năm)**, đây là điều kiện bắt buộc
của Apple, không có cách nào bỏ qua.

## Bước 1: Đăng ký Apple Developer

Như bước 1 trong [ios-app-store.md](ios-app-store.md). Làm trên trình duyệt
hoặc app **Apple Developer** trên iPhone. Ghi lại **Team ID** (10 ký tự) ở
https://developer.apple.com/account → Membership details.

## Bước 2: Tạo mã gói (Bundle ID)

1. https://developer.apple.com/account/resources/identifiers/list → **+**.
2. Chọn **App IDs** → **App** → Continue.
3. Description: `Factory Tycoon 3D`. Bundle ID: chọn **Explicit**, điền
   `com.ltt13012001.factorytycoon3d`. Không cần bật Capability nào. Bấm
   Continue → Register.

## Bước 3: Tạo app trên App Store Connect

Như bước 4 trong [ios-app-store.md](ios-app-store.md): Apps → **+** → New App,
chọn Bundle ID vừa tạo.

## Bước 4: Tạo khóa API App Store Connect

Khóa này cho máy Mac của GitHub quyền ký và tải app lên thay bạn.

1. https://appstoreconnect.apple.com/access/integrations/api → tab
   **Team Keys**. Lần đầu bấm **Request Access** rồi đồng ý.
2. Bấm **+** (Generate API Key). Name: `GitHub Actions`. Access: **Admin**
   (cần quyền Admin để Apple tự tạo chứng chỉ phát hành).
3. Ghi lại **Issuer ID** (dòng trên cùng của trang) và **Key ID** của khóa.
4. Bấm **Download** để tải file `AuthKey_XXXXXXXXXX.p8`. Apple **chỉ cho tải
   một lần**, hãy cất giữ cẩn thận và không gửi cho ai.

## Bước 5: Thêm secrets vào GitHub

Mở https://github.com/ltt13012001/factory-tycoon-3d/settings/secrets/actions
→ **New repository secret**, tạo đủ 4 cái:

| Tên | Giá trị |
|---|---|
| `APPLE_TEAM_ID` | Team ID ở bước 1 |
| `ASC_KEY_ID` | Key ID ở bước 4 |
| `ASC_ISSUER_ID` | Issuer ID ở bước 4 |
| `ASC_KEY_P8` | Toàn bộ nội dung file `.p8` (mở bằng Notepad, chép cả dòng `-----BEGIN PRIVATE KEY-----` và `-----END PRIVATE KEY-----`) |

Secrets được GitHub mã hóa, không ai xem được kể cả trong log.

## Bước 6: Chạy build

Cách dễ nhất, làm được trên điện thoại:

1. Vào https://github.com/ltt13012001/factory-tycoon-3d/releases/new.
2. **Choose a tag** → gõ `ios-v0.10.0` → Create new tag.
3. **Target**: chọn nhánh có bản mới nhất (`main` sau khi gộp PR, hoặc
   `claude/project-thread-nccnew`).
4. Điền tiêu đề bất kỳ, tích **Set as a pre-release**, bấm **Publish release**.

Vào tab **Actions** của repo để xem tiến trình, mất khoảng 15–25 phút. Dấu ✓
xanh nghĩa là đã tải lên Apple. Mỗi lần muốn gửi bản mới, tạo một tag mới
(`ios-v0.10.1`, `ios-v0.11.0`…). Số build tự tăng nên không lo trùng.

Khi workflow đã nằm trên nhánh `main`, có thể chạy thẳng: tab Actions →
**iOS TestFlight** → **Run workflow**.

## Bước 7: Thử và gửi duyệt

1. Sau 10–30 phút, bản build hiện ở App Store Connect → app → **TestFlight**.
2. Cài app **TestFlight** trên iPhone, thêm chính bạn vào Internal Testing để
   chơi thử trên máy thật.
3. Làm tiếp bước 6 và 7 trong [ios-app-store.md](ios-app-store.md): điền
   thông tin, ảnh chụp màn hình (đã có sẵn), chọn build và gửi duyệt. Tất cả
   làm trên trình duyệt.

## Khi build báo lỗi

Mở lần chạy bị đỏ trong tab Actions, bấm vào bước bị lỗi và chép đoạn log
cuối gửi cho Claude. Các lỗi hay gặp:

- `Missing repository secrets`: thiếu secret ở bước 5, hoặc gõ sai tên.
- `No profiles for 'com.ltt13012001.factorytycoon3d'` hoặc lỗi chứng chỉ:
  chưa tạo Bundle ID (bước 2), hoặc khóa API không phải quyền Admin.
- Lỗi upload báo app không tồn tại: chưa tạo app trên App Store Connect
  (bước 3), hoặc Bundle ID chọn khi tạo app khác với mã trong game.
- `runs-on: macos-26` không có máy: sửa thành `macos-15` trong file workflow.

## Cách khác nếu không dùng GitHub Actions

- **Codemagic** (codemagic.io): dịch vụ build trên Mac đám mây, có gói miễn
  phí 500 phút/tháng, cũng dùng khóa API ở bước 4.
- **Thuê Mac đám mây** (MacinCloud, AWS EC2 Mac…): điều khiển một máy Mac từ
  xa qua trình duyệt rồi làm theo [ios-app-store.md](ios-app-store.md). Tốn phí
  theo giờ hoặc tháng.
- **Mượn máy Mac** của bạn bè trong khoảng một giờ, làm theo
  [ios-app-store.md](ios-app-store.md).
