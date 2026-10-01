# MySQL cho app nhân viên

Database `smartres_staff` dùng MySQL trên máy. Script setup thêm 8 bàn và 6 món khởi tạo; không tạo đơn hay doanh thu giả. Các đơn mới do người dùng thao tác trong app được lưu thật, tồn tại sau khi đóng app và khởi động lại server.

## Khởi động backend

Từ `D:\DoAn4\SmartRes`:

```powershell
npm --workspace apps/api run dev:staff
```

Thông tin kết nối nằm trong `.env.mysql.local`, được Git bỏ qua. Không đưa file chứa mật khẩu lên GitHub. Backend nhân viên ở cổng 4000 chỉ lắng nghe localhost. Backend JSON chặng 3 ở cổng 4010 là bài học cũ riêng biệt.

## Chạy app Android

```powershell
flutter emulators --launch Medium_Phone
& 'C:\Users\quang\AppData\Local\Android\sdk\platform-tools\adb.exe' -s emulator-5554 reverse tcp:4000 tcp:4000
cd D:\DoAn4\SmartRes\smartresapp
flutter run -d emulator-5554 -t lib/main_staff.dart
```

`adb reverse` nối localhost:4000 của Android đến máy tính; chạy lại sau khi khởi động máy ảo. Nếu ID thiết bị khác, xem `flutter devices`. Bản debug cho phép HTTP tới localhost. Bản phát hành cần HTTPS và đăng nhập/phân quyền.

## Thử dữ liệu

1. Chọn A01 → Nhận bàn → chọn số khách → Xác nhận.
2. Mở A01 → Gọi thêm món → thêm 2 cơm và 1 trà → Gửi đơn gọi món.
3. Mục Phục vụ hiển thị các món, tổng 115.000 đ.
4. Mở lại app hoặc bấm Tải lại: bàn và đơn vẫn còn.
5. Khi bếp cập nhật món sang `completed`, nhân viên có thể xác nhận phục vụ; API lưu `served` và `served_at`.

Chưa có màn hình bếp cập nhật `completed`, thu ngân chốt thanh toán/giải phóng bàn, hoặc đăng nhập. App tải lại dữ liệu mỗi 5 giây và có nút làm mới. Luồng này chưa dùng WebSocket.

## Xem trong MySQL Workbench

Kết nối MySQL local, làm mới Schemas rồi chọn `smartres_staff`. Chạy:

```sql
USE smartres_staff;
SELECT id, code, area, seats, guests, status FROM restaurant_tables;
SELECT id, name, price, is_available FROM menu_items;
SELECT id, order_code, table_id, total_amount, created_at FROM orders;
SELECT id, order_id, item_name, quantity, unit_price, status, served_at FROM order_items;
```

Giá trong đơn được lưu tại thời điểm đặt; thay giá menu không đổi đơn cũ. API chỉ nhận mã món và số lượng, tự tính giá trong transaction. `request_id` giúp thử lại cùng một yêu cầu không tạo đơn trùng.

## Khởi tạo và kiểm thử

```powershell
npm --workspace apps/api run db:staff
npm --workspace apps/api run test:staff
```

Setup chỉ thêm bàn/món còn thiếu, không đặt lại trạng thái hay sửa giá đã thay đổi. Kiểm thử dùng database tạm ngẫu nhiên `smartres_staff_test_*` và dọn database đó sau khi xong; không tạo đơn kiểm thử trong database app.
