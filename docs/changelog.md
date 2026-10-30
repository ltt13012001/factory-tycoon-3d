# Changelog

## 0.7.0 – Nhân viên đi đúng đường, khu phố kiểu Việt Nam

- Nhân viên không còn đi xuyên tường, máy, kho hàng hay hàng rào: đường đi
  được tìm trên bản đồ lối đi của cả khu (tường có cửa, máy, chồng hàng, bàn
  ghế, xe đỗ, bồn hoa, cây và cột đèn đều là vật cản), rồi kéo thẳng thành
  từng đoạn và bo cong ở góc rẽ.
- Lối đi bộ sơn xanh trong sân: từ cổng nhân viên, qua giữa bãi đỗ xe, tới
  cửa xưởng và dọc lối nhỏ giữa xưởng và văn phòng ra khu nghỉ. Nhân viên đi
  theo lối này thay vì băng ngang sân hay qua bãi xe tải.
- Tan ca nhân viên đi ra cổng, theo vỉa hè: người qua vạch sang đường tới
  trạm xe buýt, người đi dọc vỉa hè về hai phía. Sáng hôm sau đi vào lại
  đúng đường đó. Nhân viên mới cũng đi vào từ cổng.
- Chuyển động mượt hơn: tăng tốc từ từ khi bắt đầu đi, chậm lại khi tới nơi,
  quay người êm, dáng đi hoà dần thay vì giật giữa đứng và đi; khi phải vội
  (nhân viên kho, tua nhanh) thì sải chân dài hơn, chạy bộ, người hơi chúi
  về trước. Tốc độ đi khi tua nhanh có giới hạn nên không còn "bay" qua map.
- Khu phố đối diện là dãy nhà ống một trệt một lầu: tạp hoá, quán cà phê
  có bàn ghế nhựa, tiệm sửa xe, nhà có cửa xếp; mái hiên, bảng hiệu, ban
  công có lan can và chậu cây, bồn nước inox, máy nước nóng năng lượng mặt
  trời, mái thái, mái tôn, phơi đồ trên sân thượng, xe máy dựng trước nhà.
- Đường phố: cây vỉa hè trong bồn (cây xanh, bằng lăng tím, phượng đỏ), cột
  điện bê tông với dây điện, dây cáp chằng chịt. Xe máy chở người đội mũ bảo
  hiểm chạy hai chiều, đi đúng làn bên phải; xe máy đi ngược chiều lách qua
  xe tải đang đỗ trước cổng thay vì đi xuyên qua. Xe cùng làn chạy cùng tốc
  độ nên không xe nào đi xuyên xe nào.
- Ruộng lúa có nước, bờ ruộng, ruộng lúa chín vàng; nhà ngói thay kho thóc
  kiểu Mỹ, đụn rơm, bụi tre dọc bờ ruộng, dừa và chuối quanh hồ.
- Mây tự ẩn khi phóng to camera gần để không che màn hình.

## 0.6.0 – Nhân viên chibi, chạy được trên nhiều máy hơn

- Nhân viên và chủ xưởng theo kiểu chibi: đầu to tròn, mắt to long lanh có
  đốm sáng, má hồng, thân tròn, tay chân ngắn; biết chớp mắt, nghiêng đầu,
  đi lạch bạch, mắt lim dim khi mệt. Mỗi bộ phận gộp thành một khối nên vẽ
  nhẹ hơn trước (khoảng một nửa số lần vẽ mỗi người).
- Đồ họa 3 mức Thấp / Vừa / Cao và Tự động (Menu → Đồ họa). Tự động chọn theo
  máy: trình duyệt dùng chip đồ họa yếu, vẽ bằng phần mềm (máy tắt tăng tốc
  phần cứng) hoặc máy 2 GB RAM chạy mức Thấp. Đang chơi mà khung hình dưới
  22 hình/giây thì tự hạ một mức. Mức Thấp: tắt bóng đổ, bloom, khử răng cưa,
  vẽ cảnh 3D ở 60% độ phân giải, khóa 30 hình/giây trên điện thoại và web.
- Trang web của game: trình duyệt cũ (iOS dưới 16.4, Android WebView cũ trong
  Zalo, Messenger) giải nén game bằng JavaScript thay vì báo lỗi; màn hình
  quá nét chỉ vẽ tối đa gấp 2 (đỡ tốn bộ nhớ đồ họa); nếu lần trước game bị
  tắt giữa chừng khi tải (máy thiếu bộ nhớ) thì lần sau tự vào chế độ nhẹ.
  Báo lỗi bằng tiếng Việt kèm cách sửa (thiếu WebGL 2, thiếu bộ nhớ, mạng
  yếu, đang mở trong Zalo/Messenger) và nút "Tải lại" / "Chơi chế độ nhẹ".

## 0.5.0 – Nhân viên sống động

- Sửa lỗi nhân viên đứng yên co giật khi không có đơn hàng: nhân viên kho chờ
  ở cửa kho đầy bị trượt qua lại mỗi tick. Giờ họ chỉ lấy hàng khi kho còn chỗ,
  đứng yên khi phải chờ, và sau nửa giờ thì để hàng lại rồi đi nghỉ.
- Nhân viên có hình người rõ ràng: chân, tay, thân áo theo màu vai trò, đầu,
  mặt (mắt, lông mày, miệng), mũ bảo hộ; biết đi, bê hàng, ngồi, bấm máy, gõ
  sửa máy và giơ biển khi đình công.
- Bong bóng suy nghĩ hiện trên đầu theo tình huống và tâm trạng ("Kho đầy
  rồi!", "Máy hỏng rồi!", "Tăng ca mệt quá...", "Lương thấp quá..."), mặt đổi
  theo tâm trạng. Bấm vào nhân viên để xem tâm trạng và suy nghĩ.
- Khu nghỉ ngơi ngoài trời cạnh văn phòng (ghế dài, bàn, bình nước). Nhân viên
  không có việc nửa giờ thì ra đây ngồi nghỉ, có việc thì quay lại (mất ít phút
  đi bộ). Có Phòng nghỉ nhân viên thì ngồi trong phòng trước.
- Ca làm việc: ca chuẩn 8 tiếng (7:00–15:00), tăng ca 10, 12 hoặc 14 tiếng ở
  bảng Nhân sự, giờ tăng ca trả 150% lương. Hết ca nhân viên ra cổng về nhà,
  sáng hôm sau đi vào; máy cần người vận hành dừng, máy tự động vẫn chạy. Lúc
  không ai làm, thời gian trôi nhanh gấp 3. Máy làm trong 8 tiếng bằng cả ngày
  24 tiếng trước đây, nên ca chuẩn vẫn ra số hàng như cũ.
- Mức lương 70–150% (thanh kéo) và tâm trạng nhân viên. Lương thấp, tăng ca dài
  làm nhân viên bất mãn; dưới 30 điểm họ có thể đình công: cả xưởng dừng, nhân
  viên đứng ở lối đi trong xưởng giơ biển "Tăng lương!". Tăng lương hoặc bớt
  tăng ca để họ quay lại. Phòng nghỉ nhân viên thêm 8 điểm tâm trạng.
- Mua hàng: tự động mua có thanh kéo số lượng mỗi lần mua (50–1.000) và mức
  hạt nhựa còn lại thì mua (0 tới sức chứa kho).
- Giám đốc (Giám đốc sản xuất, kinh doanh, nhân sự, tài chính, quốc tế hoặc
  CEO) tự nhận các đơn làm kịp hạn; bật/tắt ở bảng Đơn hàng.
- Pallet cạnh máy chứa gấp đôi, nhân viên kho chở gấp đôi mỗi chuyến cho kịp
  máy chạy nhanh trong ca. Ước tính "cần khoảng X giờ" của đơn hàng tính theo
  giờ làm. Bản lưu cũ tự nâng cấp lên phiên bản 5.

## 0.4.0 – Từ xưởng thành tập đoàn đa quốc gia

- Camera: kéo chuột trái hoặc một ngón để di chuyển, vuốt nhanh để camera lướt
  tiếp, xoay hai ngón để xoay tự do (nút Xoay quay 45°), phạm vi di chuyển rộng
  tới các lô đất mới. Trên iPad và điện thoại có bàn điều hướng: mũi tên (giữ
  để di chuyển), + / − phóng to, "Về" quay lại nhà máy chính.
- Tốc độ sản xuất: "Cải tiến dây chuyền" 5 cấp (+10% mỗi cấp cho mọi máy),
  máy nâng cấp được tới cấp 5.
- Xưởng trưởng: tuyển ở bảng Nhân sự hoặc Mở rộng, máy nhanh hơn 15%, tự gọi
  sửa máy hỏng khi không có kỹ thuật viên rảnh. Đi tuần quanh các máy.
- Bảng "Mở rộng": đặt đủ máy thì mua lô đất bên cạnh, xây Xưởng 2, 3, 4 (thấy
  trong 3D, từ đất bán đến công trường và nhà xưởng có dây chuyền). Mỗi xưởng
  cần xưởng trưởng, mua dây chuyền và tự động hoá để tăng lãi.
- Các cấp doanh nghiệp: Xưởng sản xuất → Công ty TNHH → Tổng công ty → Tập
  đoàn → Tập đoàn đa quốc gia. Công ty mở được chi nhánh trong nước (Bình Dương,
  Bắc Ninh, Hải Phòng, Đà Nẵng), Tổng công ty mở chi nhánh nước ngoài (Thái Lan,
  Indonesia, Ấn Độ, Mexico, Đức, Hoa Kỳ). Mỗi nơi phải khảo sát thị trường
  trước, chi nhánh cần giám đốc chi nhánh.
- Ban lãnh đạo theo từng cấp: Giám đốc sản xuất, Kế toán trưởng, Giám đốc kinh
  doanh, Giám đốc nhân sự, Giám đốc tài chính, Giám đốc khu vực quốc tế, Tổng
  giám đốc điều hành; mỗi người có lương và hiệu quả riêng.
- Lãi và chi phí của các xưởng, chi nhánh và lương lãnh đạo được ghi vào báo
  cáo cuối ngày. Bản lưu cũ tự nâng cấp lên phiên bản 3.
- Cân bằng lại kinh tế (người chơi thường bị lỗ): mọi máy chạy nhanh gấp đôi
  (tiền điện mỗi sản phẩm giữ nguyên), khách đặt nhiều đơn hơn và đơn lớn gấp
  đôi, vốn đầu $3.000, lương và thuê đất $30/ngày, phí tuyển $50, hạn mức thấu
  chi $1.500, nhân viên kho chở nhiều và đi nhanh hơn. Dây chuyền ở xưởng mới
  và chi nhánh lãi gấp 2,5 lần. Bản lưu cũ có ít hơn $3.000 được bù lên $3.000.
  `tests/balance_report.gd` in diễn biến tiền của một người chơi điển hình.

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
