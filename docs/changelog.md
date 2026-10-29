# Changelog

## Chưa phát hành: đồ hoạ chân thực hơn

Theo góp ý: đồ hoạ nên thực tế hơn, cảnh quan và máy móc nhà xưởng chi tiết hơn.

- Ánh sáng: bóng mềm, sương xa làm mờ đồi núi, bloom nhẹ cho đèn và cửa sổ ban
  đêm, bầu trời có mặt đất và mặt trời. Vật liệu mới: sơn bóng, thép, kính,
  nước, mặt đất có vân (cỏ, nhựa đường, bê tông không còn một màu phẳng).
- Nhà xưởng: tường sau cao có cửa sổ, cột thép, đường ống nước, ống cứu hỏa,
  máng cáp, tủ điện, bảng tên xưởng; tường thấp bằng tôn có gân, cột chắn ở cửa;
  sàn epoxy với ô máy kẻ vàng và lối đi; bàn nguội, máy nén khí; kho có xe nâng,
  cửa cuốn, vạch khu hàng; hạt nhựa đóng bao jumbo trên pallet gỗ; văn phòng có
  bàn ghế, màn hình, tủ sách, sofa, cây cảnh. Tường sau tự ẩn khi xoay camera ra
  phía sau để không che máy.
- Máy móc: cả 5 loại máy có bệ, chân, vạch an toàn, bảng điều khiển có màn
  hình, đèn tháp tín hiệu; máy ép có trục ép, xi lanh có vòng gia nhiệt, phễu;
  máy thổi có tủ kính; máy công nghiệp có tay gắp và băng tải; máy dập có
  rèm sáng an toàn và nút hai tay; máy tự động có cánh tay robot 6 trục.
- Xe tải, ô tô có cửa kính, đèn, cản, bánh có mâm, thùng có pallet.
- Cảnh quan: silo hạt nhựa và máy làm lạnh sau xưởng, trạm biến áp, chốt bảo vệ
  và barie, đường có bó vỉa, vạch kẻ, vạch qua đường, trạm xe buýt, đường điện;
  nhà dân có cửa sổ, cửa chính, ống khói, hàng rào, hộp thư; xưởng bên cạnh có
  cửa cuốn, ống khói sơn sọc, bồn chứa; hồ có lau sậy, lá sen, đá, cầu gỗ;
  nông trại có kho thóc, silo, rơm, máy cày, ruộng lúa chín; đồi có rừng thông,
  hàng nghìn bụi cỏ, cây nhiều tán, bụi cây, đá, mây nhiều lớp.
- Hiệu năng: mọi vật tĩnh được gộp thành vài lưới (MeshBatch), giảm mạnh số lệnh vẽ
  so với trước (mỗi khối hộp từng là một lệnh vẽ riêng). Bầu trời chỉ
  cập nhật vài giây một lần thay vì mỗi khung hình. Máy yếu (web, di động) dùng
  ít cây, ít cỏ và bản đồ phản chiếu nhỏ hơn.

## 0.3.0 – Bản di động

- Chạy trên Android và iOS (màn hình ngang), có preset xuất cho cả hai và
  icon ứng dụng. Xem `docs/mobile.md`.
- Điều khiển cảm ứng: kéo một ngón để di chuyển, chụm hai ngón để phóng to,
  xoay hai ngón hoặc bấm nút Xoay để xoay, chạm để chọn và đặt máy. Nút Quay
  lại của Android đóng bảng đang mở.
- Giao diện cho màn hình nhỏ: tự chọn cỡ giao diện theo kích thước màn hình,
  tránh tai thỏ, thanh thông tin gọn hơn trên màn hình hẹp, bảng bên co theo
  chiều rộng, báo cáo cuối ngày cuộn được, ít thông báo hơn cùng lúc.
- Đồ họa trên điện thoại dùng renderer Mobile (tự lùi về OpenGL ES 3), tắt
  SSAO, bóng đổ nhẹ hơn.
- Tự lưu khi chuyển ứng dụng xuống nền.

## 0.2.0

Theo góp ý chơi thử: giao diện nhỏ, chữ chưa rõ, ít tương tác, ít máy và cảnh.

- Giao diện: chữ to hơn khoảng 20%, nút bấm và bảng rộng hơn, nút A+ / A− trong
  Menu để phóng to cả giao diện (lưu lại cho lần sau), chữ trong cảnh 3D to và
  có viền. Cảnh báo máy hỏng là nút bấm, đưa thẳng tới máy hỏng.
- Sản phẩm mới: bình nước (2 hạt nhựa) và kệ lưu trữ (5 hạt nhựa), mỗi loại
  có khách hàng riêng. Kho thành phẩm hiện màu theo sản phẩm.
- 5 loại máy: máy ép cơ bản, máy thổi bình, máy ép công nghiệp, máy ép kệ,
  máy ép tự động (không cần người). Máy mới mở khóa theo ngày và uy tín.
- Máy có cấp 1 đến 3 (mỗi cấp nhanh hơn 15%), độ bền giảm dần, có thể hỏng.
  Chủ xưởng sửa có tính phí, hoặc thuê kỹ thuật viên tự đi bảo trì.
- 5 công trình: mở rộng kho (2 cấp), mở rộng xưởng (+3 ô máy), phòng kinh
  doanh (+40% đơn), điện mặt trời bãi xe (−40% tiền điện), phòng nghỉ (nhân
  viên kho đi nhanh hơn 25%). Có công trường, giàn giáo, thợ xây và % tiến độ.
- Tự động mua hạt nhựa và tự động giao đơn đủ hàng (bật tắt được).
- Cảnh quan: chu kỳ ngày đêm theo giờ game (ngày bắt đầu 7:00), đèn đường và
  cửa sổ sáng về đêm, nhà hàng xóm, xưởng cơ khí có ống khói, tạp hóa, hồ nước,
  cánh đồng, đồi, tua-bin gió, mây trôi, xe chạy trên đường, bãi đỗ xe, cổng
  và cột cờ, bồn hoa.
- Lưu game phiên bản 2, tự chuyển đổi file lưu của bản 0.1.

## 0.1.0 – Prototype 0.1

- Xưởng nhựa một sản phẩm (hộp nhựa) với máy ép cơ bản, tối đa 6 ô máy.
- Đơn hàng khách nhỏ: nhận, từ chối, hết hạn, giữ hàng cho đơn sớm hạn nhất,
  giao hàng bằng xe tải, phạt trễ và uy tín.
- Mua hạt nhựa theo lô 100 / 250 / 500, xe tải giao sau 2 giờ game.
- Công nhân vận hành và nhân viên kho, tuyển và cho nghỉ.
- Chi phí cuối ngày (lương, thuê đất, điện, lãi thấu chi) và báo cáo ngày.
- Hướng dẫn 5 bước, giao diện tiếng Việt, camera isometric xoay 4 hướng.
- Lưu JSON có phiên bản, tự lưu 60 giây, test headless.
