# Factory Tycoon 3D (Quản Lý Nhà Máy)

Game 3D Idle Tycoon về quản lý nhà máy, viết bằng **Godot 4.7.2 + GDScript**.
Đây là **bản 0.8**, chơi được trên Windows, Android, iOS và trình duyệt: một xưởng nhựa làm hộp, bình nước và kệ lưu trữ với 5 loại
máy, nâng cấp và sửa máy, kỹ thuật viên, 5 công trình mở rộng, chu kỳ ngày đêm,
ca làm và tăng ca, tâm trạng và đình công, mở rộng thành tập đoàn đa quốc gia
và khu phố xung quanh. Xem thay đổi trong `docs/changelog.md`.

## Chơi thử

- **Windows:** chạy `FactoryTycoon3D.exe` (bản xuất sẵn, không cần cài gì).
- **Android:** cài file `.apk`. **iOS:** cần máy Mac và Xcode. Xem
  `docs/mobile.md` (điều khiển cảm ứng, cách cài và cách tự build).
- **Trình duyệt:** mở link game; xem `docs/web.md` (máy nào chạy được, chế độ
  nhẹ, cách tự build trang web).
- **Từ mã nguồn:** mở thư mục này bằng Godot 4.7.2 rồi bấm Play (F5).

Điều khiển:

| Thao tác | Phím / chuột |
|---|---|
| Xoay camera 90° | Q / E |
| Phóng to, thu nhỏ | Lăn chuột |
| Di chuyển camera | Kéo chuột phải hoặc chuột giữa, WASD, phím mũi tên |
| Chọn máy hoặc công nhân | Bấm chuột trái |
| Phóng to / thu nhỏ giao diện | Menu → A+ / A− |
| Đồ họa Tự động / Thấp / Vừa / Cao | Menu → Đồ họa |
| Tạm dừng / tiếp tục | Space |
| Hủy chế độ xây / bỏ chọn | Esc |

Game tự lưu mỗi 60 giây và khi thoát, vào `user://saves/slot_1.json`
(trên Windows: `%APPDATA%\Godot\app_userdata\Factory Tycoon 3D\saves\`).

## Kiểm thử

```bash
# Unit test lõi + test trọn vòng 10 ngày + test lưu/tải (headless)
tests/run.sh                       # hoặc: godot --headless --path . --script res://tests/run_tests.gd

# Mở cảnh chính 30 giây, người chơi tự động điều khiển game ở tốc độ x4
godot --headless --path . --fixed-fps 60 --quit-after 1800 -- --smoke-test

# Chụp ảnh màn hình (cần màn hình hoặc xvfb-run)
godot --path . -- --screenshot=/tmp/shots
```

Xuất bản: `godot --headless --path . --export-release "Windows Desktop" build/windows/FactoryTycoon3D.exe`
(cần export templates 4.7.2). Android và iOS: xem `docs/mobile.md`.

## Kiến trúc

Lõi mô phỏng (`core/`) là GDScript thuần, không phụ thuộc node, chạy theo tick
cố định 0,25 giây. Một ngày game = 1440 tick = 6 phút thật. Tiền tính bằng
**cent (số nguyên)** để sổ thu chi khớp tiền mặt đến từng đơn vị. Thế giới 3D
và giao diện chỉ đọc trạng thái lõi và nghe sự kiện qua `EventBus`.

```
autoload/      EventBus, GameManager, TimeManager, SaveManager
core/          Simulation, GameState, Economy/Inventory/Production/Order/Employee/BuildingManager,
               Tutorial, SaveMigrations, ContentDB, Fmt
data/defs/     Định nghĩa Resource (máy, sản phẩm, nguyên liệu, mẫu đơn, công trình, kinh tế)
data/content/  Số liệu cân bằng (.tres), sửa ở đây không cần sửa code
scenes/        main.tscn, machines/, actors/
scripts/view/  Thế giới 3D: camera, nhà xưởng, máy, công nhân, xe tải, công trình,
               cảnh quan, ngày đêm
scripts/ui/    Giao diện: thanh thông tin, 5 bảng quản lý, báo cáo ngày
tests/         Trình chạy test, các bộ test, người chơi tự động, smoke test
assets/fonts/  Be Vietnam Pro (SIL OFL 1.1)
```

Tài liệu thiết kế: xem `docs/design.md`.
