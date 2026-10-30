# Bản trình duyệt

Game chạy trong trình duyệt bằng bản Web của Godot (renderer Compatibility,
WebGL 2, một luồng).

## Máy nào chạy được

| Máy | Yêu cầu |
|---|---|
| iPhone, iPad | iOS / iPadOS 15 trở lên (Safari hoặc bất kỳ trình duyệt nào) |
| Android | Chrome bản mới, Android 8 trở lên, nên có 3 GB RAM trở lên |
| Máy tính | Chrome, Edge, Firefox hoặc Safari bản mới, bật tăng tốc phần cứng |

Không chạy được trên máy không có WebGL 2 (iOS 14 trở xuống, trình duyệt rất
cũ). Trang sẽ báo rõ lý do và cách sửa.

## Khi người chơi không mở được

- **Mở trong Zalo, Messenger, Facebook:** trình duyệt trong ứng dụng đôi khi
  bị giới hạn. Bấm ••• → Mở bằng trình duyệt (Chrome hoặc Safari).
- **Máy yếu, máy thiếu bộ nhớ:** bấm "Chơi chế độ nhẹ" (đồ họa Thấp, vẽ ít
  điểm ảnh hơn). Trang tự bật chế độ này nếu lần trước bị tắt khi đang tải.
  Chọn lại mức đồ họa ở Menu → Đồ họa thì thoát chế độ nhẹ.
- **Màn hình đen, chạy rất chậm trên máy tính:** bật "Dùng tăng tốc phần cứng"
  (Chrome: Cài đặt → Hệ thống) rồi tải lại.
- **Mạng yếu:** game tải khoảng 10 MB lần đầu.

## Mức đồ họa

| | Thấp | Vừa | Cao |
|---|---|---|---|
| Bóng đổ | tắt | một bản đồ bóng (web), hai lớp (máy khác) | hai lớp |
| Độ phân giải cảnh 3D | 60% (web), 75% | 75% (web), 100% | 100% |
| Bloom, chỉnh màu, khử răng cưa | tắt | bật | bật |
| Đèn sân ban đêm | tắt | tắt trên web | bật |
| Giới hạn khung hình (web, di động) | 30 | không | không |

Giao diện luôn vẽ ở độ nét đầy đủ. Lựa chọn lưu trong `user://settings.cfg`.
Chạy thử một mức: `godot --path . -- --quality=low` (low, medium, high).

## Tự build trang web

```bash
GODOT=/duong/dan/godot tools/build_web_artifact.sh
```

Kết quả ở `build/web-artifact/`: `index.html` (trang tải game, lấy từ
`web/index.html`), `index.js`, hai file worklet âm thanh, `engine-gz.wasm`
(engine nén gzip), `game-pck.wasm` (dữ liệu game) và `fflate.js` (bộ giải nén
dự phòng cho trình duyệt cũ). Đăng cả thư mục lên một máy chủ web hoặc
Artifact.
