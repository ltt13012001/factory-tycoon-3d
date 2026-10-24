# Thiết kế Prototype 0.1

Tài liệu thiết kế đầy đủ (Bước 2–6: kiến trúc, phạm vi, vòng lặp, công thức
kinh tế, tài nguyên và kiểm thử) nằm ở Claude Docs:
https://claude.ai/artifact/PG4yY3oRbjYQg1s9yo4vxD

## Khác biệt so với tài liệu khi lập trình

- **Godot 4.7.2** (bản ổn định mới nhất khi cài).
- **Pallet cạnh máy chứa tối đa 20 hộp.** Nhân viên kho mang hộp từ pallet vào
  kho thành phẩm (10 hộp mỗi chuyến) và mang hạt nhựa từ bãi giao nhận vào kho
  nguyên liệu (25 bao mỗi chuyến). Không có nhân viên kho thì pallet đầy và máy
  dừng, hàng ở bãi không vào kho được.
- **Công nhân đi theo các điểm cửa cố định** thay vì NavigationAgent3D, vị trí
  bám đúng số tick còn lại của từng chuyến hàng trong lõi.
- **Giao diện và cảnh con dựng bằng code** trên một Theme chung, nên chỉ có các
  file `.tscn` gốc (main, máy, công nhân, xe tải).
- **Nhân sự** là một bảng riêng (tuyển vận hành / nhân viên kho, cho nghỉ).
- **Xe khách** mất 15 giây thật (60 tick): vào bãi, chất hàng, rời đi; tiền về
  khi xe rời bãi.
- **Âm thanh** chưa có (chưa có file CC0), không chặn bản 0.1.

## Tiêu chí hoàn thành và kết quả

| Tiêu chí | Kết quả |
|---|---|
| Test tự động mô phỏng 10 ngày không lỗi, tiền khớp sổ thu chi | Đạt (`test_full_loop.gd`) |
| Lưu rồi tải lại cho trạng thái giống hệt | Đạt (`test_save.gd`, `test_full_loop.gd`) |
| Mở cảnh chính headless 30 giây không lỗi script | Đạt (smoke test) |
| Bạn chơi bản Windows, mua được máy thứ hai không cần hướng dẫn ngoài | Chờ bạn chơi thử |
