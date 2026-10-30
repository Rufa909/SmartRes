# Nhân viên xem món đã gọi theo bàn — 30/10/2026

## Cách sử dụng

1. Đăng nhập app nhân viên, mở **Sơ đồ bàn** và chạm vào bàn muốn kiểm tra.
2. Chi tiết hiển thị trạng thái bàn, số khách, món đã gọi, số lượng, đơn giá, thành tiền, ghi chú và mã đơn.
3. Trạng thái từng món gồm **Chờ bếp → Đang nấu → Chờ phục vụ → Đã phục vụ**. Tổng số phần và **Tạm tính món** nằm trong chi tiết; số này chưa trừ giảm giá thu ngân áp dụng.
4. Màn hình tự tải lại mỗi 5 giây khi đang mở; có nút **Tải lại chi tiết bàn** để cập nhật ngay. Danh sách dài có thể cuộn.
5. Từ chi tiết vẫn có **Nhận bàn**, **Gọi thêm món**, **Yêu cầu thanh toán** theo trạng thái hiện tại. Bàn chưa gọi món sẽ không bật yêu cầu thanh toán.

## Xử lý dữ liệu và lỗi

- API `GET /api/staff/tables/:id/details` chỉ cho nhân viên và quản lý, yêu cầu Bearer token; bếp không được gọi API này.
- Đọc theo ID bàn, chỉ lấy đơn chưa thanh toán và chưa hủy của bàn đang dùng/chờ thanh toán. Đơn của bàn khác, đơn hủy và món của lượt đã thanh toán không xuất hiện.
- Bàn trống hoặc chưa gọi món có thông báo riêng. Khi thu ngân thanh toán, lần cập nhật tiếp theo xóa món cũ và chuyển sang thao tác nhận bàn.
- Tải thất bại sẽ hiện lỗi, có **Thử lại**; các thao tác bị khóa để tránh dùng trạng thái cũ. Nếu trước đó có dữ liệu thì ghi rõ dữ liệu có thể đã cũ.
- Không thay đổi schema, không cần import/xóa database.

## File thay đổi

- `apps/api/src/staff-app.ts`: API đọc chi tiết bàn, kiểm tra phân quyền, tổng tiền từ các dòng món.
- `smartresapp/lib/staff_api.dart`: hàm gọi API chi tiết.
- `smartresapp/lib/staff_table_details.dart`: màn hình chi tiết và cập nhật định kỳ.
- `smartresapp/lib/staff_page.dart`: chạm bàn mở màn hình mới, giữ các thao tác nhận bàn/gọi món/thanh toán.
- Các test Flutter và test MySQL: hiển thị chi tiết, lỗi/thử lại, danh sách 25 món trên màn hình nhỏ, không lẫn bàn/đơn hủy/lượt đã thanh toán.

## Cập nhật và kiểm thử

Chạy backend mới bằng `npm --workspace apps/api run dev:staff` tại thư mục gốc. App Flutter đang chạy thì hot restart; bản cài APK cần build/cài lại để có giao diện mới:

```powershell
cd smartresapp
flutter build apk --debug -t lib/main_staff.dart --no-pub
```

Kiểm tra: Flutter 31/31 bài đạt; test tích hợp MySQL nhân viên/thu ngân và bảo mật đều đạt trong database tạm. Backend TypeScript đạt. Kết quả analyzer/build APK được ghi thêm trong nhật ký chung.
