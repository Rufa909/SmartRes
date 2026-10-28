# Hóa đơn thu ngân

Mã hóa đơn mới có dạng `2810-A02-1930`: ngày tháng `DDMM`, số/mã bàn, giờ nhận bàn `HHmm` (4 số) theo giờ Việt Nam, không có năm. Mã giữ nguyên khi sửa món, thanh toán, xem lịch sử và in lại. Thời điểm nhận bàn được lưu khi nhân viên nhận bàn; lượt cũ chưa có dữ liệu này dùng thời điểm đơn đầu tiên. Hóa đơn đã lưu trước bản cập nhật giữ nguyên mã cũ. Ngày giờ hiển thị trên hóa đơn và bản in dùng `DD/MM HH:mm:ss`, không có năm.

1. Nhân viên bấm **Yêu cầu thanh toán** ở bàn, hoặc khách bấm **Yêu cầu thanh toán** trên trang gọi món sau khi đặt đơn thành công.
2. Màn hình thu ngân tự tải lại mỗi 5 giây. Bấm **Xem chi tiết hóa đơn** để kiểm tra mã hóa đơn, bàn, ngày giờ Việt Nam, từng món, số lượng, đơn giá, thành tiền và tổng cộng.
3. Các nút **− / +** và **thùng rác** nằm cùng hàng với tên món; mỗi thao tác tự lưu và tính lại tổng tiền. Số lượng tối thiểu là 1, tối đa 99; hóa đơn cần ít nhất một món. Bấm **Thêm món** → **Chọn món**, nhập số lượng và **Ghi chú món mới**, rồi **Thêm vào hóa đơn**. Cửa sổ này chỉ chứa các món mới, không sửa lại món đã có. Món mới được gửi bếp cùng ghi chú. Món cũ giữ giá tại thời điểm đặt, món thêm lấy giá hiện tại.
4. Chọn **Tiền mặt**, **Chuyển khoản** hoặc **Thẻ**. Ngay bên dưới có **Giảm giá**: chọn **Nhập %** (0–100%, tối đa 2 số thập phân) hoặc **Mã voucher**, rồi bấm **Áp dụng**. Mỗi bill chỉ dùng một hình thức giảm giá; đổi hình thức sẽ thay thế mức giảm trước đó. **Bỏ giảm giá** trả bill về tiền món ban đầu. Phần này hiển thị tiền món, tiền giảm và số tiền cần thanh toán. Bấm **Xác nhận thanh toán** để chốt bill. Khi còn món chưa phục vụ, nút vẫn bấm được và hiển thị hộp thoại “Đơn hàng còn N món chưa phục vụ. Bạn có chắc chắn muốn thanh toán ngay không?”. Chọn **Hủy** để quay lại hoặc **Xác nhận thanh toán** để chốt ngay; trạng thái phục vụ của món được giữ nguyên trong hóa đơn. Thao tác này ghi nhận phương thức đã thu tiền; không tự thực hiện giao dịch với ngân hàng hay máy quẹt thẻ.
5. Sau khi xác nhận thành công, bấm **In hóa đơn** để mở hộp thoại in của thiết bị. Bill dùng giấy cuộn **80 mm**, lề 4 mm, chiều dài tự co theo số món. Mỗi món gồm tên và dòng số lượng × đơn giá, thành tiền; không dùng bảng kẻ ô. Phông tiếng Việt kèm trong ứng dụng, không cần tải phông qua mạng lúc in. Chọn máy in nhiệt và giấy 80 mm trong driver, giữ tỉ lệ in 100%.
6. Bấm **Lịch sử** trên màn hình thu ngân để tìm theo mã hóa đơn hoặc bàn, xem ngày giờ, phương thức, tổng tiền, người thu ngân, mở chi tiết và in lại. Lịch sử được lưu trong MySQL, vẫn còn sau khi đóng app hoặc khởi động lại máy chủ. Danh sách phân trang 30 hóa đơn mỗi trang. Hóa đơn đã thanh toán chỉ xem/in; sửa sai trước khi chốt.

API nhân viên có xác thực: `GET /api/staff/tables/:id/invoice`, `POST /api/staff/tables/:id/pay`. API khách: `POST /api/orders/:orderCode/request-payment`, dùng mã đơn ngẫu nhiên nhận khi đặt món. Đơn đã thanh toán/hủy không thể yêu cầu thanh toán cho lượt khách mới.

Khởi động lại API nhân viên, API khách và build lại ứng dụng Flutter sau khi cập nhật vì tính năng in bổ sung plugin native `printing`. Windows cần bật Developer Mode hoặc chạy môi trường build có quyền tạo symlink. Chưa kiểm chứng bản in trên máy in vật lý.

## Lưu trữ và cập nhật database

API nhân viên tự tạo bảng bổ sung khi khởi động. Có thể chạy riêng `npm --workspace apps/api run db:invoices` để tạo `cashier_invoices` (bản chi tiết tại lúc chốt) và `invoice_adjustments` (người sửa, ghi chú, trước/sau). Việc ghi nhận thanh toán và lưu hóa đơn nằm trong cùng transaction. Máy chủ dùng phiên bản hóa đơn để từ chối ghi đè/thanh toán từ màn hình đã cũ.

Các đơn đã thanh toán trước khi có tính năng lịch sử được khôi phục theo bàn, thời điểm và phương thức thanh toán. Dữ liệu cũ không có số khách/người thu ngân lúc chốt sẽ hiển thị chưa ghi nhận; không lấy thông tin của lượt khách mới. Hóa đơn mới được lưu độc lập với các lần đổi giá hoặc tái sử dụng bàn.

## Voucher và giảm giá

`cashier_vouchers` lưu mã, phần trăm giảm, tiền món tối thiểu, trạng thái và thời gian áp dụng; `invoice_discounts` lưu lựa chọn cho bill đang mở. Không tạo mã khuyến mãi giả trong database ứng dụng. Để dùng một mã thực tế, cấu hình bản ghi tương ứng trong `cashier_vouchers` với `percentage` từ 0 đến 100; các trường `starts_at`/`ends_at` có thể để NULL. Mã không tồn tại, ngừng hoạt động, ngoài thời hạn hoặc chưa đủ tiền món sẽ bị từ chối. Nhập % thủ công dùng được ngay khi chưa cấu hình voucher.

Máy chủ kiểm tra lại voucher khi chốt và tự tính lại tiền giảm khi sửa số lượng/thêm/xóa món. Tiền giảm làm tròn đến đồng, không vượt tiền món. Lịch sử và bill in lưu tiền món, phần trăm, mã voucher (nếu có), tiền giảm, số tiền thực thu. `orders.total_amount` vẫn lưu tiền món; `cashier_invoices.total_amount` là số tiền sau giảm.
