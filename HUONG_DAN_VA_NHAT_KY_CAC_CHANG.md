# SmartRes — Hướng dẫn và nhật ký các chặng

Cập nhật: **03/10/2026**. Tài liệu dành cho bạn bắt đầu từ chưa biết Flutter. Số chặng dưới đây được thống nhất theo các phần đã làm trong thư mục dự án.

## 1. Dự án hiện tại là gì?

Mục tiêu: khách quét QR để gọi món trên web; nhân viên, bếp và quản lý sử dụng app Flutter. Backend dùng Node.js, dữ liệu lưu MySQL.

Hiện tại đã có app Android Flutter cho **nhân viên và bếp**, chạy trên máy ảo Android. App gọi API Node.js và lưu đơn thật vào MySQL trên máy tính. Đây là bản phát triển để học và thử quy trình; chưa hoàn thành toàn bộ sản phẩm nhà hàng.

Luồng đã có:

**Nhận bàn → Gọi món → Bếp nhận món → Bắt đầu nấu → Hoàn thành món → Nhân viên xác nhận đã phục vụ.**

Chưa có thu ngân chốt hóa đơn và trả bàn về trống, đăng nhập/phân quyền, hay luồng QR khách hàng kết nối đầy đủ vào hệ thống MySQL này. Chưa tạo bản cài iPhone. Bản đang chạy là Android trên máy ảo Windows.

### Phân biệt các bản để khỏi mở nhầm

| Phần | Điểm chạy | Nguồn dữ liệu |
| --- | --- | --- |
| Bài học Dart chặng 1 | `hoc_flutter/chang_01/main.dart` | Dữ liệu trong mã |
| Bài học menu khách chặng 2–3 | `smartresapp/lib/main.dart` | Backend JSON cổng 4010 |
| App nhân viên hiện tại | `smartresapp/lib/main_staff.dart` | API cổng 4000 → MySQL |
| Màn hình bếp hiện tại | Nút bếp trong app nhân viên | Cùng API 4000 → MySQL |
| Điểm chạy bếp riêng để phát triển | `smartresapp/lib/main_kitchen.dart` | Cùng API 4000 → MySQL |

Trang `http://127.0.0.1:5178/#/staff` là bản chạy trong trình duyệt. Để xem app Android riêng, sử dụng máy ảo và lệnh `flutter run` bên dưới. Hai điểm chạy nhân viên/bếp hiện dùng cùng mã ứng dụng Android; chưa đóng gói thành hai ứng dụng cài song song.

## 2. Nhật ký từng chặng

### Chặng 1 — Làm quen Dart

**Đã làm:** chương trình console mô phỏng menu, món ăn và giỏ hàng. Có lớp `MonAn`, `DongGioHang`, kiểm tra món còn bán và tính tổng tiền. Ví dụ 2 cơm giá 45.000 đồng và 1 trà giá 25.000 đồng có tổng 115.000 đồng.

**Bạn học:** biến, kiểu dữ liệu, danh sách, điều kiện, vòng lặp, hàm và lớp. Dart là ngôn ngữ dùng để viết Flutter.

**Xem và chạy lại:**

```powershell
cd D:\DoAn4\hoc_flutter\chang_01
& C:\flutter\bin\cache\dart-sdk\bin\dart.exe run main.dart
```

Bài tập: đổi số lượng món rồi dự đoán tổng trước khi chạy. Phần này chưa có giao diện, API hoặc database.

### Chặng 2 — Giao diện Flutter đầu tiên

**Đã làm:** màn hình menu, thẻ món, tìm kiếm, lọc danh mục, thêm món và giỏ hàng. Bản đầu chỉ giữ dữ liệu trong bộ nhớ.

**Bạn học:** widget là thành phần giao diện; `Scaffold` tạo khung màn hình; danh sách dựng nhiều món; `setState` yêu cầu Flutter vẽ lại khi dữ liệu thay đổi.

Ghi chú bài học nằm tại `D:\DoAn4\hoc_flutter\chang_02\README.md`. Mã `smartresapp/lib/main.dart` đã được phát triển tiếp sang chặng 3, không còn là bản chặng 2 độc lập.

### Chặng 3 — Flutter gọi backend Node.js

**Đã làm:** backend học tập tại `D:\DoAn4\hoc_flutter\chang_03\server.mjs`, cung cấp menu và nhận đơn qua HTTP. Đơn lưu vào `orders.json`. Backend tự tính giá và xử lý yêu cầu gửi lại để hạn chế đơn trùng. Giao diện báo lỗi khi gửi thất bại và giữ giỏ để thử lại.

**Bạn học:** API là điểm giao tiếp app–server; JSON là định dạng dữ liệu; `Future`, `async`, `await` giúp chờ kết quả mạng.

Chạy lại backend bài học nếu cần:

```powershell
cd D:\DoAn4\hoc_flutter\chang_03
node server.mjs
```

Backend này dùng **cổng 4010 và file JSON**, tách biệt với MySQL hiện tại. Không cần mở nó khi chạy app nhân viên. Ghi chú chi tiết nằm trong README cùng thư mục.

### Chặng 4 — App nhân viên và máy ảo Android

**Đã làm:** giao diện danh sách bàn, khu vực, chi tiết bàn, gọi món, danh sách phục vụ và phần tài khoản. Đã chuẩn bị Android Studio, SDK và máy ảo `Medium_Phone` để chạy app Flutter Android.

**Bạn học:** một dự án Flutter có thể có nhiều điểm chạy. Chọn `lib/main_staff.dart` sẽ mở giao diện nhân viên. Máy ảo là thiết bị Android giả lập trên máy tính, nơi cài và chạy ứng dụng Android.

Giao diện nhân viên lúc đầu dùng dữ liệu mẫu; sang chặng 5 đã chuyển sang API/MySQL. Mục tài khoản hiện chưa phải chức năng đăng nhập thật.

### Chặng 5 — Kết nối MySQL thật

**Đã làm:** database `smartres_staff`, API riêng cho app nhân viên, nhận bàn, tạo đơn, xem trạng thái, yêu cầu thanh toán và xác nhận phục vụ. Bàn và đơn lưu trong MySQL nên còn sau khi đóng app hoặc khởi động lại backend.

Dữ liệu khởi tạo gồm 8 bàn và 6 món. Không tạo đơn hàng hay doanh thu giả. Giá món là dữ liệu ban đầu để thực hành, có thể thay đổi trong quá trình phát triển.

Backend tính giá từ database, kiểm tra số lượng và tình trạng bàn/món. Tạo đơn sử dụng transaction; `request_id` giúp thử lại cùng yêu cầu mà không tạo thêm đơn. Đơn lưu tên và giá món lúc đặt, vì vậy sửa giá menu không làm đổi đơn cũ.

**Bạn học:** database lưu dữ liệu lâu dài; bảng có dòng và cột; khóa ngoại liên kết đơn với bàn và món; transaction giúp nhóm thay đổi được lưu trọn vẹn hoặc hủy khi lỗi.

### Chặng 6 — Bếp nhận món và nhân viên phục vụ

**Đã hoàn thiện:** màn hình bếp có ba nhóm Chờ bếp, Đang nấu, Chờ phục vụ. Thẻ món hiện bàn, tên món, số lượng, mã đơn và thời gian. Bếp bấm **Bắt đầu nấu**, sau đó **Hoàn thành món**. Nhân viên xác nhận đã mang món ra bàn.

Có nút mở bếp trong thanh trên cùng của màn hình nhân viên. Đây là cách chuyển màn hình để thử quy trình; chưa phải phân quyền người dùng.

Trạng thái từng dòng món:

| Giá trị trong database | Hiển thị/ý nghĩa | Thao tác tiếp theo |
| --- | --- | --- |
| `preparing` | Chờ bếp | Bắt đầu nấu |
| `cooking` | Đang nấu | Hoàn thành món |
| `completed` | Chờ phục vụ | Nhân viên xác nhận phục vụ |
| `served` | Đã phục vụ | Rời hàng đợi bếp |

Backend kiểm tra thứ tự trạng thái, không cho bỏ qua bước nấu hoặc chuyển món đã phục vụ về bếp. Khi API báo lỗi, app không giả vờ cập nhật thành công.

Màn hình bếp tải lại mỗi **3 giây**, nhân viên mỗi **5 giây**, đồng thời có thao tác làm mới. Chưa dùng WebSocket hoặc thông báo âm thanh.

Ngày 03/10/2026: dọn phần import/nút bếp bị lặp, chuẩn hóa định dạng Flutter, hoàn thiện kiểm tra và tổng hợp tài liệu này.

## 3. Cách mở dự án hằng ngày

### Bước 1 — Chạy backend ở terminal thứ nhất

MySQL Windows service `MySQL94` cần đang chạy. Cấu hình kết nối nằm trong `D:\DoAn4\SmartRes\.env.mysql.local`. File này chứa thông tin riêng tư và đã được Git bỏ qua; không chép mật khẩu vào tài liệu hoặc commit file đó.

```powershell
cd D:\DoAn4\SmartRes
npm --workspace apps/api run dev:staff
```

Khi thành công sẽ thấy `Staff API + MySQL: http://127.0.0.1:4000`. Giữ terminal này chạy trong lúc dùng app.

Có thể mở `http://127.0.0.1:4000/api/health` để kiểm tra kết nối. Đây là API, không phải trang giao diện.

### Bước 2 — Mở máy ảo ở terminal thứ hai

Nếu máy ảo đã mở thì bỏ qua lệnh khởi động, chỉ kiểm tra thiết bị.

```powershell
& C:\flutter\bin\flutter.bat emulators --launch Medium_Phone
& C:\flutter\bin\flutter.bat devices
```

Đợi Android khởi động xong. Thiết bị hiện dùng ID `emulator-5554`; nếu danh sách trả ID khác thì thay trong các lệnh tiếp theo.

### Bước 3 — Nối API và chạy app

```powershell
& 'C:\Users\quang\AppData\Local\Android\sdk\platform-tools\adb.exe' -s emulator-5554 reverse tcp:4000 tcp:4000
cd D:\DoAn4\SmartRes\smartresapp
& C:\flutter\bin\flutter.bat run -d emulator-5554 -t lib/main_staff.dart
```

`adb reverse` chuyển kết nối cổng 4000 từ Android về backend trên máy tính. Chạy lại sau khi khởi động lại máy ảo. Bản debug cho phép HTTP tới localhost. Cấu hình hiện tại phục vụ phát triển trên máy, chưa phải kết nối cho thiết bị ngoài mạng.

App có tên **SmartRes Nhân viên**. Mở màn hình bếp bằng biểu tượng bếp ở thanh trên cùng; dùng nút quay lại để trở về nhân viên.

Nếu máy đã nhận lệnh `flutter`, có thể dùng `flutter` thay cho đường dẫn đầy đủ. Khi `flutter run` đang chạy, phím `r` tải lại mã giao diện; `R` khởi động lại app; `q` kết thúc phiên chạy. Dừng backend bằng `Ctrl+C` khi không cần nữa.

**Không cần khởi tạo database mỗi lần mở.** Nếu cài môi trường lần đầu hoặc cần thêm dữ liệu khởi tạo còn thiếu:

```powershell
cd D:\DoAn4\SmartRes
npm --workspace apps/api run db:staff
```

Script chỉ thêm dữ liệu còn thiếu; không đặt lại bàn, xóa đơn hoặc đổi giá bạn đã sửa.

## 4. Tự thử một vòng nghiệp vụ

1. Mở app nhân viên, chọn một bàn đang trống và nhận bàn với số khách phù hợp.
2. Mở bàn đó, chọn gọi thêm món, thêm món rồi gửi đơn. Với giá khởi tạo, 2 cơm 45.000 đồng và 1 trà 25.000 đồng là 115.000 đồng.
3. Mở màn hình bếp. Đơn xuất hiện trong Chờ bếp; nếu chưa thấy, bấm làm mới hoặc chờ một nhịp tải.
4. Bấm Bắt đầu nấu trên món, chuyển sang nhóm Đang nấu.
5. Bấm Hoàn thành món. Món chuyển sang Chờ phục vụ.
6. Quay về nhân viên, mở phần phục vụ và xác nhận mang món ra bàn. Món được lưu là `served`.
7. Tải lại hoặc đóng/mở app để xem trạng thái vẫn còn. Đơn đã gửi nằm trong MySQL; giỏ chưa gửi không được đảm bảo lưu qua lần mở app.

Bạn có thể thử bếp với một món trước rồi thực hiện các món còn lại. Đây là thao tác tạo dữ liệu thật trong database phát triển.

**Lưu ý về thanh toán:** nút yêu cầu thanh toán hiện chỉ đổi bàn sang `waiting_payment`. Chưa có chức năng thu ngân kết thúc hóa đơn và giải phóng bàn; khi học luồng bếp nên dừng ở bước phục vụ, tránh chuyển tất cả bàn sang chờ thanh toán.

Trạng thái bàn, đơn và từng dòng món là các trường khác nhau. Hoàn thành nấu món chưa đồng nghĩa đơn đã thanh toán hay bàn đã trống.

## 5. Xem dữ liệu trong MySQL Workbench

Đăng nhập kết nối MySQL local đang dùng, làm mới Schemas, rồi chạy các truy vấn chỉ đọc sau:

```sql
USE smartres_staff;
SELECT id, code, area, seats, guests, status FROM restaurant_tables;
SELECT id, name, price, is_available FROM menu_items;
SELECT id, order_code, table_id, total_amount, payment_status, created_at FROM orders;
SELECT id, order_id, item_name, quantity, unit_price, status, served_at FROM order_items;
```

Năm bảng chính: `restaurant_tables` lưu bàn; `categories` lưu nhóm món; `menu_items` lưu thực đơn; `orders` lưu đơn; `order_items` lưu các dòng món trong đơn.

## 6. Đọc mã ở đâu?

Các đường dẫn dưới đây tính từ `D:\DoAn4\SmartRes`:

| File | Vai trò |
| --- | --- |
| `smartresapp/lib/main_staff.dart` | Khởi động app nhân viên |
| `smartresapp/lib/staff_page.dart` | Giao diện bàn, gọi món, phục vụ |
| `smartresapp/lib/kitchen_page.dart` | Hàng đợi và thao tác bếp |
| `smartresapp/lib/staff_api.dart` | Flutter gọi HTTP API |
| `apps/api/src/staff-server.ts` | Khởi động backend nhân viên/bếp |
| `apps/api/src/staff-app.ts` | Các API và kiểm tra nghiệp vụ |
| `apps/api/src/config/env.ts` | Đọc cấu hình môi trường |
| `apps/api/src/infrastructure/database.ts` | Kết nối MySQL |
| `database/staff-schema.sql` | Cấu trúc bảng và dữ liệu khởi tạo |
| `apps/api/scripts/setup-staff-db.mjs` | Thiết lập database |
| `apps/api/scripts/staff.integration.test.ts` | Kiểm tra luồng với MySQL |
| `smartresapp/test/kitchen_test.dart` | Kiểm tra thao tác bếp và lỗi API |

Nên đọc theo thứ tự: `main_staff.dart` → `staff_page.dart` → `staff_api.dart` → `staff-app.ts` → schema. Ví dụ khi bấm gửi món: giao diện lấy giỏ → API client gửi JSON → Node.js kiểm tra → MySQL lưu → app nhận kết quả và tải lại danh sách.

### API đang sử dụng

| Phương thức và đường dẫn | Chức năng |
| --- | --- |
| `GET /api/health` | Kiểm tra dịch vụ và MySQL |
| `GET /api/staff/snapshot` | Lấy dữ liệu bàn, menu, món đang xử lý |
| `POST /api/staff/tables/:id/seat` | Nhận bàn |
| `POST /api/staff/orders` | Tạo đơn |
| `POST /api/staff/items/:id/kitchen` | Chuyển sang nấu hoặc hoàn thành |
| `POST /api/staff/items/:id/serve` | Xác nhận phục vụ |
| `POST /api/staff/tables/:id/request-payment` | Yêu cầu thanh toán |

## 7. Kiểm thử và kết quả

Ngày 03/10/2026 đã chạy:

- `flutter analyze`: không phát hiện vấn đề.
- `flutter test`: 7 kiểm thử đạt, gồm gọi API, giỏ hàng, nhân viên và bếp.
- Backend TypeScript typecheck: đạt.
- Kiểm thử tích hợp MySQL: đạt; bao gồm giá từ server, chống đơn trùng, trạng thái bếp/phục vụ, xung đột và dữ liệu sau khi khởi động lại HTTP server.
- Đã build APK debug, cài và khởi chạy qua `flutter run` trên `emulator-5554`. API health trả `status: ok`, `storage: mysql`.

Giới hạn kiểm tra giao diện lần này: công cụ chụp cửa sổ máy ảo báo `window crop is outside captured monitor`, nên chưa xác minh hình ảnh trực tiếp trên máy ảo. Kết quả build/chạy và kiểm thử ở trên đã xác nhận; bạn có thể thử giao diện theo mục 4.

Lệnh chạy lại:

```powershell
cd D:\DoAn4\SmartRes\smartresapp
& C:\flutter\bin\flutter.bat analyze
& C:\flutter\bin\flutter.bat test
cd D:\DoAn4\SmartRes
npm --workspace apps/api run typecheck
npm --workspace apps/api run test:staff
```

Kiểm thử MySQL tạo database tạm tên ngẫu nhiên `smartres_staff_test_*` và xóa chính database đó khi xong. Tài khoản chạy kiểm thử cần quyền tạo/xóa database kiểm thử. Nó không tạo đơn trong database app. Các kiểm thử Flutter dùng HTTP giả lập; bài kiểm thử tích hợp mới thực sự truy cập MySQL.

## 8. Lỗi thường gặp

| Hiện tượng | Cách kiểm tra |
| --- | --- |
| App không kết nối được | Backend 4000 có đang chạy? MySQL có hoạt động? Chạy lại `adb reverse` |
| MySQL báo Access denied | Kiểm tra tài khoản trong `.env.mysql.local` bằng Workbench; không gửi mật khẩu vào log |
| Cổng 4000 đang được dùng | Có thể backend đã mở ở terminal khác; dùng phiên đang chạy, tránh khởi động trùng |
| Không thấy máy ảo | Chạy `flutter devices`, đợi Android khởi động xong; kiểm tra Device Manager trong Android Studio |
| App mở menu khách thay vì nhân viên | Lệnh chạy cần có `-t lib/main_staff.dart` |
| Bếp không có món | Cần gửi đơn thật từ bàn đang dùng; giỏ chưa gửi chưa phải đơn |
| API trả 409 | Trạng thái đã thay đổi hoặc thao tác không còn hợp lệ; tải lại rồi kiểm tra bàn/món |
| Đã hoàn thành mà nhân viên chưa thấy | Chờ chu kỳ tải lại hoặc bấm làm mới |
| Đóng app rồi giỏ chưa gửi mất | Giỏ chỉ đang trong bộ nhớ; chỉ đơn gửi thành công mới được lưu MySQL |

Không xóa database để chữa lỗi giao diện hoặc trạng thái; cần tìm nguyên nhân trước để giữ dữ liệu đang có.

## 9. Các chặng tiếp theo dự kiến

1. **Thu ngân và kết thúc lượt ăn:** tổng hợp các đơn của bàn, lập hóa đơn, xác nhận thanh toán, chống xác nhận hai lần, trả bàn về trống và giữ lịch sử. Chặng này chưa làm.
2. **Đăng nhập và phân quyền:** nhân viên, bếp, quản lý có quyền API riêng; không chỉ ẩn/hiện nút trên giao diện.
3. **Khách quét QR:** nhận diện bàn/lượt ăn, xem menu, đặt món vào cùng luồng MySQL và hạn chế yêu cầu không hợp lệ.
4. **Quản lý:** sửa menu, bật/tắt món, quản lý bàn và báo cáo từ hóa đơn đã thanh toán.
5. **Hoàn thiện vận hành:** cập nhật tức thời nếu cần, xử lý mất mạng, HTTPS, sao lưu và đóng gói bản cài.

Đây là kế hoạch học và phát triển, không phải danh sách tính năng đã hoàn thành. Mỗi chặng nên có một luồng dùng được, kiểm tra lỗi và cập nhật lại tài liệu này.
