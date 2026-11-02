# Giảm giá và khuyến mãi theo khung giờ

Vào **Quản lý → Truy cập nhanh → Giảm giá và khuyến mãi** để thấy ba mục lớn: **Khuyến mãi**, **Giảm giá**, **Các đơn đã áp dụng**. Chọn **Khuyến mãi** mới mở danh sách và biểu mẫu chương trình. Mục **Giảm giá** hiện để trống theo yêu cầu, chưa nối thêm chức năng. **Các đơn đã áp dụng** hiển thị hóa đơn đã thanh toán có tiền giảm thực tế lớn hơn 0, hỗ trợ tìm, phân trang và xem/in lại chi tiết. Dùng Flutter/Dart, API Express/TypeScript và MySQL hiện có.

## Cấu hình

- Tên chương trình; giảm theo phần trăm (tối đa 100%, hai chữ số thập phân) hoặc số tiền nguyên đồng.
- Giới hạn giảm tối đa: để trống nếu không giới hạn. Hóa đơn tối thiểu: để trống hoặc 0 nếu không yêu cầu.
- Chỉ áp dụng cho **toàn hóa đơn**, dựa trên tổng tiền món trước giảm, chưa thanh toán.
- Công tắc **Bật chương trình** là trạng thái `isActive`. Tắt công tắc ở danh sách để tạm dừng ngay.
- **Áp dụng liên tục 24/7** (`isAlwaysActive`) bỏ qua giới hạn giờ, thứ và khoảng ngày, nhưng vẫn phải bật chương trình và đủ giá trị hóa đơn. Không tự hết hạn đến khi quản lý tắt.
- Biểu mẫu luôn hiện phần **Chọn ngày và giờ áp dụng**, nút **Chọn khoảng ngày**, **Giờ bắt đầu**, **Giờ kết thúc** và các thứ T2–CN. Chương trình mới mặc định dùng lịch. Chọn ngày/giờ sẽ tự tắt 24/7; chọn một giờ sẽ tự chuyển từ nguyên ngày sang khung giờ cố định. Có thể bật lại 24/7 nếu muốn bỏ các giới hạn thời gian. Dùng **giờ Việt Nam, GMT+7**, không dùng giờ thiết bị của thu ngân.
- Bắt đầu được tính, kết thúc không được tính. Ví dụ 14:00–17:00 áp dụng từ 14:00:00 đến trước 17:00:00. Khoảng ngày gồm cả ngày đầu và ngày cuối.
- Khung giờ qua đêm được hỗ trợ khi giờ kết thúc nhỏ hơn giờ bắt đầu. Ví dụ T6 22:00–02:00 được dùng lúc 01:00 T7; thứ và khoảng ngày được tính theo ngày bắt đầu khung (T6). Muốn đủ 24 giờ, chọn nguyên ngày, không đặt giờ đầu/cuối giống nhau.

## Áp dụng vào hóa đơn

Ở chi tiết hóa đơn thu ngân, mở **Giảm giá → Khuyến mãi**, chọn chương trình đủ điều kiện rồi bấm **Áp dụng**. Có thể **Bỏ giảm giá**. Mỗi hóa đơn dùng một chương trình hoặc voucher hoặc giảm % thủ công, không cộng dồn. Các chương trình đủ điều kiện hiện số tiền giảm được tính cho hóa đơn đó.

Máy chủ kiểm tra lại điều kiện khi áp dụng, khi đọc lại hóa đơn và khi chốt thanh toán. Nếu quản lý tắt chương trình, ngoài thời gian áp dụng hoặc tiền món không đủ tối thiểu, ưu đãi bị từ chối; thu ngân cần bỏ/đổi ưu đãi trước khi chốt. Thay đổi món tính lại giảm giá và trần. Tiền giảm làm tròn đến đồng, không vượt tổng tiền món và không vượt trần.

Bill in và lịch sử lưu tên chương trình, kiểu/giá trị giảm, trần và số tiền đã giảm trong snapshot hóa đơn. Đổi chương trình sau này không sửa hóa đơn đã thanh toán. Hai thiết bị sửa cùng phiên bản chương trình sẽ nhận lỗi xung đột thay vì ghi đè nhau.

## API và mã nguồn

- Quản lý: `GET/POST /api/staff/management/promotions`, `POST /api/staff/management/promotions/:id` (kèm `version`), `POST /api/staff/management/promotions/:id/status` (`version`, `isActive`).
- Thu ngân/quản lý: `GET /api/staff/tables/:id/promotions`; `POST /api/staff/tables/:id/discount` với `mode: "promotion"`, `promotionId`, `version` hóa đơn.
- `apps/api/src/promotions.ts` xuất `checkPromoApplicable(order, promotion, now?)` trả boolean và `evaluatePromotion(...)` trả `{applicable, reason, discountAmount}`. `order` có `subtotalAmount`, `paymentStatus`. `now` chỉ dùng để kiểm thử, không nhận từ request thu ngân.
- Database: `promotions` và `invoice_promotions`, được tạo bổ sung khi API nhân viên khởi động; không tạo sẵn chương trình giả. Có thể chạy riêng `npm --workspace apps/api run db:promotions`.

Kiểm thử: `npm --workspace apps/api run test:promotions`; Flutter: `flutter test test/promotion_management_test.dart test/cashier_test.dart` trong thư mục `smartresapp`.
