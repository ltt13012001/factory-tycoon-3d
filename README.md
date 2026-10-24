# Factory Tycoon 3D (Quản Lý Nhà Máy)

Game 3D Idle Tycoon về quản lý nhà máy, viết bằng **Godot 4.7.2 + GDScript**.
Đây là **Prototype 0.1**: một xưởng nhựa nhỏ làm hộp nhựa, chơi trọn vòng
nhận đơn, mua nguyên liệu, sản xuất, giao hàng, trả chi phí và mua máy thứ hai.

## Chơi thử

- **Windows:** chạy `FactoryTycoon3D.exe` (bản xuất sẵn, không cần cài gì).
- **Từ mã nguồn:** mở thư mục này bằng Godot 4.7.2 rồi bấm Play (F5).

Điều khiển:

| Thao tác | Phím / chuột |
|---|---|
| Xoay camera 90° | Q / E |
| Phóng to, thu nhỏ | Lăn chuột |
| Di chuyển camera | Kéo chuột phải hoặc chuột giữa, WASD, phím mũi tên |
| Chọn máy hoặc công nhân | Bấm chuột trái |
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
(cần export templates 4.7.2).

## Kiến trúc

Lõi mô phỏng (`core/`) là GDScript thuần, không phụ thuộc node, chạy theo tick
cố định 0,25 giây. Một ngày game = 1440 tick = 6 phút thật. Tiền tính bằng
**cent (số nguyên)** để sổ thu chi khớp tiền mặt đến từng đơn vị. Thế giới 3D
và giao diện chỉ đọc trạng thái lõi và nghe sự kiện qua `EventBus`.

```
autoload/      EventBus, GameManager, TimeManager, SaveManager
core/          Simulation, GameState, Economy/Inventory/Production/Order/EmployeeManager,
               Tutorial, SaveMigrations, ContentDB, Fmt
data/defs/     Định nghĩa Resource (máy, sản phẩm, nguyên liệu, mẫu đơn, kinh tế)
data/content/  Số liệu cân bằng (.tres), sửa ở đây không cần sửa code
scenes/        main.tscn, machines/, actors/
scripts/view/  Thế giới 3D: camera, nhà xưởng, máy, công nhân, xe tải
scripts/ui/    Giao diện: thanh thông tin, 5 bảng quản lý, báo cáo ngày
tests/         Trình chạy test, các bộ test, người chơi tự động, smoke test
assets/fonts/  Be Vietnam Pro (SIL OFL 1.1)
```

Tài liệu thiết kế: xem `docs/design.md`.
