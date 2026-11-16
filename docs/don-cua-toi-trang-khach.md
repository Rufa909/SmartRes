# Đơn của tôi trên trang khách

Khách mở **Đơn của tôi** ở thanh điều hướng để xem các đơn đã gửi trong lượt bàn hiện tại. Mỗi đơn hiển thị mã rút gọn, thời gian, món, số lượng, ghi chú theo món, ghi chú chung của đơn, trạng thái từng món và tổng tiền. Ghi chú chung trong giỏ được gửi vào `orders.customer_note` khi xác nhận gọi món. Trạng thái được tải lại mỗi 5 giây; có nút tải lại thủ công.

API `GET /api/orders/mine/:tableCode` yêu cầu token bàn hiện hành. Backend chỉ trả đơn có `dining_session_id` khớp token và bàn đã xác thực, nên không thể dùng mã bàn để xem đơn của lượt khác. Khi chưa gửi đơn, màn hình báo giỏ chưa phải đơn. Khi bàn đã chờ thanh toán, màn hình báo đang chờ thu ngân; trong lúc bàn còn phục vụ, khách có thể gửi yêu cầu thanh toán từ đơn.

Thu ngân thanh toán xong thì phiên bị thu hồi theo luồng hiện tại. Trang khách không cung cấp lịch sử hóa đơn đã chốt; lịch sử đó thuộc màn hình thu ngân.
