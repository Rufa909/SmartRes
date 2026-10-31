# Tổng quan và doanh thu quản lý — 31/10/2026

## Màn hình mới

Tài khoản `manager` vào thẳng **Tổng quan nhà hàng** thay cho danh sách chức năng đơn giản trước đây. Trang có:

- Thẻ doanh thu đã thu, số hóa đơn, trung bình mỗi hóa đơn và tổng giảm giá đã ghi nhận.
- So sánh với khoảng liền trước có cùng số ngày. Nếu kỳ trước không có doanh thu thì không tính phần trăm để tránh chia cho 0.
- Bộ lọc Hôm nay, 7 ngày, Tháng này, Tùy chọn. Khoảng tùy chọn tối đa 366 ngày; mặc định xem 7 ngày gần nhất.
- Biểu đồ doanh thu từng ngày; ngày không có hóa đơn được điền 0. Có thể cuộn ngang và nhấn giữ cột để xem giá trị chính xác khi khoảng ngày dài.
- Vận hành hiện tại: bàn đang dùng/bàn trống/chờ thanh toán, số khách, phần món chờ bếp/chờ phục vụ và món hết bán.
- Tiền món chưa thu được tách riêng, trước giảm giá, không cộng vào doanh thu đã thu.
- Top 5 món bán chạy theo số phần; giá trị món hiển thị trước giảm giá.
- Thống kê tiền mặt/chuyển khoản/thẻ và 5 hóa đơn gần nhất trong khoảng chọn. Chạm hóa đơn để xem chi tiết; Xem tất cả mở lịch sử thanh toán.
- Các lối vào quản lý thực đơn, vận hành bàn, bếp, thu ngân và thanh điều hướng dưới cùng.

## Doanh thu được tính thế nào?

**Doanh thu đã thu = tổng `cashier_invoices.total_amount` của hóa đơn có `paid_at` trong khoảng ngày.** Đây là số tiền sau giảm giá đã chốt, không lấy giá menu hiện tại và không cộng đơn chưa thanh toán. Không nhân tổng hóa đơn theo số dòng món.

Ngày báo cáo dùng giờ Việt Nam `Asia/Ho_Chi_Minh` (UTC+7), gồm ngày đầu và ngày cuối. Ví dụ 31/10 lấy từ 31/10 00:00 đến trước 01/11 00:00 theo giờ Việt Nam. Truy vấn so sánh thời điểm bằng epoch để không phụ thuộc MySQL đang đặt UTC hay UTC+7.

Món bán chạy đọc từ snapshot hóa đơn đã chốt, giữ tên/giá lúc bán. Không lấy giá mới của menu để tính lịch sử. Các dòng có cùng ID món nhưng tên lúc bán khác nhau được thống kê thành những dòng riêng theo tên lịch sử. Giá trị món trước giảm giá có thể lớn hơn số thực thu sau giảm giá.

Trung bình hóa đơn = doanh thu / số hóa đơn, làm tròn đồng, có tính hóa đơn giảm 100% còn 0 đồng. Thống kê giảm giá dựa trên `discountAmount` đã lưu; hóa đơn cũ thiếu trường này được xem là chưa ghi nhận giảm giá.

**Vận hành hiện tại** luôn phản ánh trạng thái đang chạy, không phải trạng thái bàn trong quá khứ của bộ lọc ngày. Báo cáo chưa tính chi phí, lợi nhuận hoặc hoàn tiền vì các nghiệp vụ đó chưa có trong hệ thống.

## Cách xem

1. Cập nhật APK/hot restart và đăng nhập vai trò quản lý (`quanly` ở bản demo local).
2. Chọn **Tháng này** để xem toàn tháng đến hiện tại, hoặc chọn **Tùy chọn** để tra khoảng cũ.
3. Kéo xuống để xem biểu đồ, top món, phương thức và hóa đơn; vuốt xuống hoặc bấm nút làm mới ở trên để tải ngay.
4. Khi màn hình đang mở, số liệu tự tải lại mỗi 30 giây. Trở lại từ các chức năng con cũng tải lại.
5. Mất kết nối sẽ hiện lỗi/Thử lại. Đổi khoảng ngày mà tải lỗi thì không hiện số liệu của khoảng cũ dưới nhãn khoảng mới.

Kiểm tra database local ngày 31/10: **tháng 10 có 697.000đ / 4 hóa đơn**; khoảng 25–31/10 hiện **0 hóa đơn**. Đây là dữ liệu đã có trong MySQL, không thêm hóa đơn giả để làm đầy biểu đồ. Số liệu sẽ thay đổi khi sử dụng tiếp.

## API và file

- `GET /api/staff/management/overview?from=YYYY-MM-DD&to=YYYY-MM-DD`, chỉ role `manager`. Không token trả 401; staff/kitchen/cashier trả 403. Dữ liệu không cache.
- Không thay schema/database cho báo cáo; sử dụng bảng hóa đơn và snapshot hiện có.
- Backend: `apps/api/src/management-overview.ts`, route trong `staff-app.ts`.
- Flutter: `smartresapp/lib/manager_page.dart`, hàm API trong `staff_api.dart`.
- Kiểm thử: `apps/api/scripts/management-overview.integration.test.ts`, `smartresapp/test/manager_overview_test.dart` và fixture riêng cho test. Fixture chỉ dùng trong kiểm thử, không hiển thị thay số liệu thật trong app.

## Kiểm chứng

```powershell
npm --workspace apps/api run test:overview
npm run typecheck
npm run build:api
```

Trong `smartresapp`: `flutter analyze --no-pub`, `flutter test --no-pub`, `flutter build apk --debug -t lib/main_staff.dart --no-pub`.

Đã kiểm tra số liệu sau giảm giá, không đếm trùng nhiều dòng món, không cộng tiền chưa thu/đơn hủy, mốc nửa đêm, ngày nhuận, khoảng rỗng, tỷ lệ kỳ trước bằng 0, quyền API, múi giờ MySQL UTC/UTC+7, bố cục màn hình nhỏ, lỗi mạng và thứ tự phản hồi khi đổi ngày nhanh. Test hồi quy nhân viên/thu ngân, bảo mật QR và quản lý thực đơn đều đạt trong database tạm riêng. Đã render và quan sát giao diện với báo cáo tháng 10 đọc từ API thật.

Không thay đổi hóa đơn, thực đơn hoặc đơn đang dùng khi kiểm tra báo cáo. Kết quả bộ kiểm thử và cập nhật APK cuối cùng ghi tại nhật ký chung.
