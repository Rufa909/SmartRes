# SmartRes — Hướng dẫn và nhật ký các chặng

Cập nhật: **07/10/2026**. Tài liệu dành cho bạn bắt đầu từ chưa biết Flutter. Số chặng dưới đây được thống nhất theo các phần đã làm trong thư mục dự án.

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

### Bổ sung chặng bếp ngày 07/10/2026

**Đã làm trong lần cập nhật này:**

- Thêm bộ lọc **Tất cả bàn / Lọc bàn A01…**. Danh sách và số đếm ở các nhóm trạng thái cùng tuân theo bàn đang chọn. Vẫn giữ lựa chọn khi món cuối của bàn đã được phục vụ để người dùng không bị chuyển sang bàn khác bất ngờ.
- Hiện **số phần và số dòng món** theo trạng thái và bàn đang xem. Ví dụ một dòng `2 × Cơm` là 2 phần nhưng chỉ 1 dòng món; số trong các nút nhóm là số dòng, không phải số phần.
- Hiện giờ đồng bộ thành công gần nhất. Nếu tải thất bại, giờ này giữ nguyên để biết dữ liệu đang cũ.
- Khi mất kết nối, giữ danh sách đã tải để tham khảo, hiển thị lỗi và khóa Bắt đầu nấu / Hoàn thành món. Nút mở lại sau lần tải thành công, qua tự cập nhật hoặc Thử lại.
- Nếu lần tải đầu thất bại, hiển thị **Chưa xác nhận được danh sách món** thay vì báo không có món.
- Cho tiêu đề hàng đợi xuống dòng trên màn hình hẹp.
- Bổ sung kiểm thử lọc bàn, tổng số phần, mất kết nối, khôi phục và lần tải đầu thất bại.

**Cách thử:** mở bếp từ app nhân viên → chọn bàn trong danh sách thả xuống → chọn Chờ bếp / Đang nấu / Chờ phục vụ → kiểm tra tổng số phần → thao tác nấu như mục 4. Muốn xem mọi bàn, chọn lại Tất cả bàn. Thứ tự ưu tiên vẫn là món nhận trước.

Để thử lỗi mạng trong môi trường phát triển, dừng backend bằng `Ctrl+C`, bấm tải lại bếp và đợi thông báo lỗi. Nút đổi trạng thái phải bị khóa. Khởi động lại backend bằng lệnh bên dưới rồi bấm Thử lại: dữ liệu tải được và nút hoạt động lại. Không cần xóa database.

**Kiểm chứng ngày 07/10/2026:** `flutter analyze` không có vấn đề; toàn bộ 9 kiểm thử Flutter đạt; kiểm thử tích hợp MySQL đạt. Không thay schema hoặc tạo đơn mẫu trong database app. Chức năng mới nằm trong `smartresapp/lib/kitchen_page.dart`, kiểm thử tại `smartresapp/test/kitchen_test.dart`.

Đợt này vẫn dùng tải định kỳ 3 giây, chưa thêm âm thanh, phân quyền bếp hoặc xử lý riêng từng phần trong cùng một dòng món. Bấm Hoàn thành món sẽ hoàn thành toàn bộ số lượng của dòng đó.

**Bản Android ngày 07/10:** đã build thành công APK debug cho máy ảo x64 tại `smartresapp/build/app/outputs/flutter-apk/app-debug.apk`. Lần build nhiều kiến trúc bị chậm ở bước tải thư viện nên đã dừng và chuyển sang đúng kiến trúc máy ảo. Lệnh build:

```powershell
cd D:\DoAn4\SmartRes\smartresapp
& C:\flutter\bin\flutter.bat build apk --debug --target-platform android-x64 -t lib/main_staff.dart
```

APK này dành cho máy ảo x64, không phải bản cài iPhone hay bản ARM cho điện thoại.

**Lần chạy xem thử tiếp theo ngày 07/10:** đã mở `Medium_Phone`, khởi động backend `dev:staff`, nối cổng bằng `adb reverse` và cài/chạy trực tiếp màn hình bếp bằng `flutter run -d emulator-5554 -t lib/main_kitchen.dart`. API health xác nhận `status: ok`, `storage: mysql`. Không tạo thêm đơn mẫu. Màn hình bếp lấy đơn hiện có; muốn nhận bàn/gọi thêm món, chạy lại điểm vào `lib/main_staff.dart` theo mục 3 rồi mở bếp từ app nhân viên. Hai điểm vào dùng cùng ứng dụng Android, không phải hai app cài riêng.

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

### Bước 3 — Chạy app trên máy ảo (cấu hình mới)

```powershell
cd D:\DoAn4\SmartRes\smartresapp
& C:\flutter\bin\flutter.bat run -d emulator-5554 -t lib/main_staff.dart
```

Từ bản giao diện mới ngày 07/10, Android mặc định gọi `http://10.0.2.2:4000`, địa chỉ máy ảo dùng để truy cập localhost của máy tính. Không cần `adb reverse` cho cấu hình này. Các đoạn nhật ký cũ bên dưới mô tả cách nối cổng của phiên bản trước. Bản debug chỉ cho HTTP tới localhost và `10.0.2.2`; chưa phải cấu hình phát hành. Tham khảo [tài liệu mạng Android Emulator](https://developer.android.com/studio/run/emulator-networking-address).

Nếu chủ động dùng điện thoại Android thật qua USB với API trên máy tính, cần chạy `adb reverse tcp:4000 tcp:4000` và truyền `--dart-define=STAFF_API_URL=http://127.0.0.1:4000` vào lệnh Flutter. Bản triển khai thực tế cần địa chỉ HTTPS riêng.

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
| `smartresapp/lib/cashier_page.dart` | Hóa đơn chờ thanh toán và xác nhận thu tiền |
| `smartresapp/lib/staff_api.dart` | Flutter gọi HTTP API |
| `apps/api/src/staff-server.ts` | Khởi động backend nhân viên/bếp |
| `apps/api/src/staff-app.ts` | Các API và kiểm tra nghiệp vụ |
| `apps/api/src/config/env.ts` | Đọc cấu hình môi trường |
| `apps/api/src/infrastructure/database.ts` | Kết nối MySQL |
| `database/staff-schema.sql` | Cấu trúc bảng và dữ liệu khởi tạo |
| `apps/api/scripts/setup-staff-db.mjs` | Thiết lập database |
| `apps/api/scripts/staff.integration.test.ts` | Kiểm tra luồng với MySQL |
| `smartresapp/test/kitchen_test.dart` | Kiểm tra thao tác bếp và lỗi API |
| `smartresapp/test/cashier_test.dart` | Kiểm tra hiển thị hóa đơn và chặn thanh toán khi còn món |

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
| `GET /api/staff/cashier` | Danh sách hóa đơn đang chờ thu ngân |
| `POST /api/staff/tables/:id/pay` | Xác nhận thanh toán và trả bàn về trống |

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

### Giao diện Figma và tiện ích nhân viên/bếp — 07/10/2026

**Thiết kế tham chiếu:** [Menu-e2, màn hình gọi món nhân viên](https://www.figma.com/design/wGOkDL5oGzLiZVmYHdPVf6/Menu-e2?node-id=1-213). Đã đọc được ngữ cảnh thiết kế và ảnh màn hình node `1:213`: màu cam đỏ `#FF5A3C`, nền xám nhạt, thẻ món bo góc hai cột, giỏ hàng nền tối. File còn có sơ đồ bàn `2:4`, bếp `1:315` và các trang chi tiết bếp; công cụ Figma báo hết lượt gói Starter trước khi đọc các màn hình đó. Vì vậy sơ đồ bàn và bếp mới chỉ đồng bộ phong cách, chưa đối chiếu đúng từng chi tiết với các trang Figma này.

**Những gì đã làm:**

- Gọi món mở thành trang đầy đủ, thay cho bảng nhỏ phải kéo lâu. Có bàn/số khách ở đầu, bộ tìm kiếm, danh mục, lưới món và tổng tiền cố định bên dưới.
- Tìm kiếm không phân biệt hoa thường và dấu tiếng Việt: `com chien`, `tra dao` đều tìm được món tương ứng; các từ có thể không liền nhau.
- Danh mục lấy từ menu MySQL. Không dùng số lượng 36 món hoặc nhãn Bán chạy giả trong bản thiết kế. Tên món, giá, trạng thái hết món và tổng tiền vẫn dùng dữ liệu thật.
- Nút Đã chọn lọc giỏ hàng; đổi tìm kiếm/danh mục không làm mất món đã chọn. Gửi lỗi giữ giỏ để thử lại, vẫn giữ cơ chế chống gửi trùng hiện có.
- Ảnh trong Figma là ảnh ô caro giữ chỗ, không phải ảnh món thật. Đã tải chính ảnh và SVG dấu cộng về `smartresapp/assets/figma`, không dùng URL Figma tạm trong giao diện. Chưa có ảnh từng món trong database.
- Thêm ô tìm bàn cho nhân viên.
- Bếp có ô tìm theo tên món/bàn/mã đơn, tìm không dấu; thêm bộ lọc Chờ từ 15 phút và thời gian chờ trên thẻ. Thời gian này tính **từ lúc đặt**, không phải thời gian bắt đầu nấu. Thứ tự vẫn ưu tiên món nhận trước.
- Thêm thông báo nổi cho nhân viên khi có món hoàn thành, hiển thị bàn cần phục vụ và nút Xem món.
- Âm báo Android phát ba tiếng cho nhóm món mới phát hiện đã hoàn thành. Theo dõi ID món nên tải lại nhiều lần không phát lặp; khi số món giữ nguyên nhưng có món mới, vẫn báo. Mở lại app sẽ báo một lần cho các món còn chờ phục vụ.
- Trong Cá nhân có bật/tắt âm báo và Thử âm báo. Lựa chọn bật/tắt lưu trên thiết bị Android. Khi tắt âm, thông báo bằng chữ vẫn hoạt động.
- Sửa kết nối mặc định của Android sang `10.0.2.2:4000` để tránh lỗi mất `adb reverse` khi mở lại máy ảo trong Android Studio.

**Giới hạn âm thanh:** chỉ triển khai âm báo native Android khi app đang hoạt động. Chưa có push notification hoặc dịch vụ nền đảm bảo thông báo lúc khóa màn hình/đóng app; iPhone/web chưa có âm báo native này. Nhân viên tải dữ liệu mỗi 5 giây, bếp mỗi 3 giây nên có độ trễ vài giây. Mất mạng thì không thể nhận trạng thái mới. Âm lượng thực tế phụ thuộc âm lượng thông báo, chế độ im lặng/Không làm phiền và thiết bị xuất âm. App không tự thay đổi âm lượng hệ thống. Nút thử tiếng xác nhận Android nhận yêu cầu phát, không chứng minh loa đã nghe được. API âm thanh sử dụng [Android ToneGenerator](https://developer.android.com/reference/android/media/ToneGenerator).

**Cách tự thử:**

1. Mở bàn đang phục vụ → Gọi thêm món → gõ `com chien` → thêm món → đổi sang `tra dao` → kiểm tra tổng tiền vẫn gồm món trước.
2. Bấm Đã chọn để xem giỏ, giảm/thêm số lượng, rồi gửi khi muốn tạo đơn thật.
3. Cá nhân → Thử âm báo; chỉnh âm lượng thông báo của Android nếu cần. Bật Âm báo món hoàn thành.
4. Mở bếp → tìm bàn/món → Bắt đầu nấu → Hoàn thành món. Trở lại nhân viên để xem thông báo và món chờ phục vụ. Khi màn hình bếp được mở từ nhân viên, màn hình nhân viên bên dưới vẫn theo dõi dữ liệu.
5. Bấm tải lại vài lần: cùng món đã báo không phát lại. Bấm Xem món rồi xác nhận phục vụ.
6. Bộ lọc chờ lâu chỉ hiện món đã đặt ít nhất 15 phút; không sửa thời gian đơn trong database để tạo kết quả giả.

**Mã chính:** `lib/order_catalogue.dart` cho giao diện gọi món; `lib/restaurant_theme.dart` cho màu sắc và tìm kiếm; `lib/ready_alert.dart` cho chống báo trùng/kênh âm; `MainActivity.kt` cho âm Android; `staff_page.dart`, `kitchen_page.dart` cho tích hợp. Không thay schema và không tạo đơn demo mới trong lần chỉnh giao diện này.

**Kết quả kiểm tra:** toàn bộ 13 kiểm thử Flutter đạt; `flutter analyze` không có vấn đề; build APK và cài vào máy ảo thành công. Đã quan sát trực tiếp màn hình gọi món với tài nguyên Figma, bộ lọc và thanh giỏ hàng; màn hình Cá nhân báo đã phát âm thử. Đã sửa màu nút gửi khi giỏ trống và áp dụng theme cả cho hộp thoại. Lần chạy cuối Flutter CLI mất kết nối log sau cài đặt; chưa xác nhận lại hình ảnh cuối vì Android Studio đang thu nhỏ. Đã kiểm tra riêng từ bên trong máy ảo tới `10.0.2.2:4000/api/health`, nhận HTTP 200 và `storage: mysql` khi không có `adb reverse`. Kiểm thử âm báo xác nhận gọi kênh native đúng một lần cho mỗi ID mới; chưa có phép đo âm lượng loa thực tế.

### Nhật ký demo thực tế ngày 07/10/2026

**Lần 1 — Demo API:** tạo đơn tại A01, 2 khách, 2 cơm chiên hải sản và 1 trà đào cam sả, tổng 115.000 đồng. Đã đi qua chờ bếp → đang nấu → hoàn thành → đã phục vụ. Đọc trực tiếp MySQL xác nhận hai dòng món có `served_at`. Kiểm tra gửi lại không trùng đơn; phục vụ sớm, bỏ qua bước nấu và đưa món đã phục vụ về nấu đều bị chặn. Kết quả lưu tại `demo-kitchen-result.json`; mã demo tại `apps/api/scripts/demo-kitchen.mjs`. Script này **tạo đơn thật trên bàn trống mỗi lần chạy**, không phải kiểm thử dùng database tạm. Không chạy lại chỉ để đọc kết quả. Lần demo này hoàn tất trong nền khi cuộc trò chuyện bị ngắt; đã kiểm tra lại trước lần tiếp theo.

**Lần 2 — Demo bấm trực tiếp trên app Android trong Android Studio:**

1. Chọn bàn A02 đang trống → Nhận bàn → xác nhận 1 khách.
2. Gọi thêm món → thêm 1 cơm chiên hải sản 45.000 đồng và 1 trà đào cam sả 25.000 đồng. Giỏ hiển thị 70.000 đồng. Lẩu hết hàng không có nút thêm.
3. Gửi đơn thành công, mã `SR-9ffdf323-77e2-4a00-9af9-91d0cbd1aaf7`.
4. Mở bếp → thấy 2 phần / 2 dòng món ở Chờ bếp → bấm Bắt đầu nấu từng món.
5. Chọn Đang nấu → Hoàn thành món từng dòng → cả hai xuất hiện ở Chờ phục vụ.
6. Quay lại nhân viên → Xác nhận đã phục vụ từng món. Danh sách đã gọi hiển thị Đã phục vụ, số món chờ về 0.
7. Về sơ đồ bàn → A02 → Yêu cầu thanh toán. Bàn chuyển sang Chờ thanh toán.
8. Đọc lại API snapshot đối chiếu: A02 có 1 khách, `waiting_payment`; hai dòng món ID 3 và 4 đều `served`. Đây là dữ liệu thật được giữ lại để xem, chưa thu tiền/chốt hóa đơn.

**Lỗi gặp và đã xử lý:** máy ảo thực tế nằm trong bảng Running Devices của Android Studio, không có cửa sổ Emulator riêng. Sau khi mở lại, `adb reverse --list` không còn cổng 4000; app hiện Không kết nối được máy chủ dù backend vẫn chạy. Chạy lại:

```powershell
& 'C:\Users\quang\AppData\Local\Android\sdk\platform-tools\adb.exe' -s emulator-5554 reverse tcp:4000 tcp:4000
& 'C:\Users\quang\AppData\Local\Android\sdk\platform-tools\adb.exe' -s emulator-5554 reverse --list
```

Sau đó đã quan sát app hiện Đã kết nối dữ liệu và thực hiện toàn bộ demo bằng giao diện. Nếu mở máy ảo hoặc cài/chạy app lại mà mất kết nối, kiểm tra và nối lại cổng sau khi thiết bị đã khởi động. Không cần sửa mật khẩu hay xóa database.

Sau demo đã chạy lại `npm --workspace apps/api run test:staff`: đạt, 1 bài kiểm thử tích hợp gồm nhiều kiểm tra nghiệp vụ, không có lỗi. Bài kiểm thử này dùng database tạm riêng, không thay đổi các đơn demo A01/A02.

### Kế hoạch sau phần bếp

### Chặng thu ngân và kết thúc lượt ăn — 15/10/2026

**Mục tiêu workflow:** `Chờ thanh toán → Thu ngân xem hóa đơn → Chọn phương thức → Xác nhận → Đóng lượt bàn → Bàn trống`.

**Đã triển khai:**

- Bổ sung `payment_method` (`cash`, `bank_transfer`, `card`) và `paid_at` vào bảng `orders`. Script setup có migration lặp an toàn, không xóa dữ liệu cũ.
- Thêm `GET /api/staff/cashier`: chỉ trả các bàn ở trạng thái `waiting_payment`, cộng tổng các đơn chưa thanh toán và đếm món chưa phục vụ.
- Thêm `POST /api/staff/tables/:id/pay`: nhận phương thức thanh toán, khóa bản ghi bàn/đơn bằng transaction, từ chối nếu còn món chưa phục vụ hoặc không còn đơn chưa thanh toán, cập nhật tất cả đơn thành đã thanh toán rồi trả bàn về `available`.
- Flutter có màn hình `CashierPage`, mở từ biểu tượng thu ngân trên app nhân viên. Mỗi thẻ hiển thị bàn, số khách, số đơn, tổng tiền; nút thanh toán bị khóa khi còn món chưa phục vụ; hộp thoại cho chọn tiền mặt, chuyển khoản hoặc thẻ.
- Thêm test widget cho thanh toán thành công và khóa thanh toán khi còn món. Mở rộng test tích hợp Node/MySQL cho tổng tiền, phương thức, `paid_at`, chống đặt thêm và trả bàn.

**Kiểm thử chặng:** TypeScript typecheck đạt; test tích hợp MySQL đạt 1/1 sau khi sửa lỗi phép `JOIN` làm nhân tổng tiền theo số dòng món; Flutter analyze đạt không có vấn đề; Flutter test đạt 15 bài; APK debug app nhân viên build thành công tại `smartresapp/build/app/outputs/flutter-apk/app-debug.apk`. Lần đầu chạy test MySQL trong sandbox gặp `EACCES 127.0.0.1:3306`, sau đó đã chạy lại với quyền kết nối MySQL cục bộ.

**Cách demo:** khởi động backend, mở app nhân viên, hoàn tất phục vụ món rồi bấm `Yêu cầu thanh toán`; mở biểu tượng thu ngân, kiểm tra tổng tiền, chọn phương thức và bấm `Xác nhận`. Sau khi thành công, hóa đơn biến mất khỏi danh sách và bàn trở về Trống. Chặng này chưa kết nối cổng ngân hàng thật, chưa in hóa đơn PDF và chưa có người thu ngân đăng nhập/audit.

2. **Đăng nhập và phân quyền:** nhân viên, bếp, quản lý có quyền API riêng; không chỉ ẩn/hiện nút trên giao diện.
3. **Khách quét QR:** nhận diện bàn/lượt ăn, xem menu, đặt món vào cùng luồng MySQL và hạn chế yêu cầu không hợp lệ.
4. **Quản lý:** sửa menu, bật/tắt món, quản lý bàn và báo cáo từ hóa đơn đã thanh toán.
5. **Hoàn thiện vận hành:** cập nhật tức thời nếu cần, xử lý mất mạng, HTTPS, sao lưu và đóng gói bản cài.

Đây là kế hoạch học và phát triển, không phải danh sách tính năng đã hoàn thành. Mỗi chặng nên có một luồng dùng được, kiểm tra lỗi và cập nhật lại tài liệu này.

### Công cụ chạy nhanh trên Windows — 15/10/2026

Đã tạo launcher để không phải gõ nhiều lệnh khi kiểm tra app:

- [SmartResLauncher.exe](D:/DoAn4/SmartRes/tools/SmartResLauncher.exe) — file chạy chính, đã nhúng sẵn script nên có thể sao chép riêng file `.exe`.
- `tools/SmartResLauncher.ps1` — mã nguồn để xem/sửa cấu hình.
- `tools/SmartResLauncher.cs` — trình bao `.exe` gọi PowerShell.

Launcher tự động kiểm tra thư mục dự án, Flutter, Android SDK và AVD `Medium_Phone`; khởi động backend Node.js nếu API chưa chạy; chờ emulator kết nối và Android khởi động xong; chạy `adb reverse tcp:4000 tcp:4000`; build APK debug nếu cần; cài APK; rồi mở app nhân viên. Có thể chạy lại không mất dữ liệu.

**Cách dùng:** nhấp đúp `SmartResLauncher.exe`. Nếu muốn bỏ qua bước build để mở nhanh APK đã build, chạy trong PowerShell:

```powershell
D:\DoAn4\SmartRes\tools\SmartResLauncher.exe -SkipBuild
```

Nếu Android Studio đặt AVD tên khác, chạy script nguồn với tham số `-AvdName Ten_AVD`; nếu thư mục dự án khác, dùng `-ProjectRoot`. Lần kiểm tra ngày 15/10/2026 đã chạy thành công: backend health OK, thiết bị `emulator-5554` kết nối, reverse cổng 4000, APK cài được và app SmartRes nhân viên mở được. Launcher cần Android Studio SDK, Flutter tại `C:\flutter` và MySQL/backend hoạt động; nó không đóng các cửa sổ backend/emulator khi kết thúc.

### Kiểm tra ổn định hệ thống — 15/10/2026

- Flutter analyzer: đạt, không có lỗi.
- Flutter test: đạt 15/15 bài.
- Backend TypeScript typecheck: đạt.
- Test tích hợp MySQL: đạt 1/1, gồm nhận bàn, chống trùng đơn, bếp, phục vụ, chờ thanh toán, khóa thanh toán khi còn món và chốt hóa đơn.
- `/api/health`: `status=ok`, `storage=mysql`.
- Kiểm tra cuối: `emulator-5554` ở trạng thái `device`, reverse `host-16 tcp:4000 tcp:4000`, tiến trình `com.example.smartresapp` đang chạy.

Lúc bắt đầu lượt kiểm tra emulator đã tắt nên ADB chưa có thiết bị; launcher đã tự bật lại và hoàn tất kiểm tra. Đây là trạng thái ổn định cho môi trường phát triển hiện tại, chưa phải bản production vì còn thiếu đăng nhập/phân quyền, HTTPS, sao lưu, push nền và cổng thanh toán thật.
