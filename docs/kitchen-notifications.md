# Chuông báo món mới cho bếp

Màn hình bếp kiểm tra đơn mới mỗi 3 giây khi đang mở. Android phát 3 tiếng báo khi có dòng món mới ở trạng thái **Chờ bếp**, kể cả món ngoài bộ lọc hiện tại. Nhiều món đến trong cùng đợt tải chỉ phát một đợt chuông.

Không báo lặp khi tải lại, mất mạng rồi kết nối lại cùng danh sách hoặc khi chuyển món sang đang nấu/hoàn thành. Nếu mở bếp khi đã có món chờ, chuông phát một lần. Âm lượng dùng mức thông báo của thiết bị. Chưa hỗ trợ báo khi đóng app.

## Khách gọi nhân viên và ghi chú đơn

Khách bấm **Gọi nhân viên** sẽ tạo yêu cầu cho lượt bàn đang hoạt động. App Nhân viên kiểm tra yêu cầu mỗi 5 giây, hiện banner và gộp số yêu cầu vào badge trên chuông thông báo; chạm chuông để xem, nhân viên bấm **Đã nhận** để đóng yêu cầu. Mỗi lượt bàn chỉ giữ một yêu cầu chờ tại một thời điểm.

Ghi chú chung nhập trong giỏ được lưu tại `orders.customer_note`. App nhân viên, chi tiết bàn và màn hình bếp đều hiển thị ghi chú này; ghi chú riêng từng món tiếp tục được lưu ở `order_items.note`.
