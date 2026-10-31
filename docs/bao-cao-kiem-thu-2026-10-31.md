# Báo cáo kiểm thử SmartRes — 31/10/2026

## Kết quả

Đạt toàn bộ 52 bài kiểm thử tự động hiện có. Backend/web kiểm tra kiểu dữ liệu thành công, Flutter analyzer không phát hiện vấn đề. Build API, web production và APK Android debug đều thành công.

| Nhóm | Kết quả | Nội dung chính |
| --- | --- | --- |
| Flutter | 39/39 | Đăng nhập, nhận bàn, giỏ hàng, tìm món, chi tiết bàn, bếp, thông báo, thu ngân, hóa đơn, thực đơn và dashboard quản lý |
| Backend tích hợp MySQL | 5/5 | Nhận bàn/gọi món/phục vụ/thanh toán, phiên QR, phân quyền, quản lý thực đơn và doanh thu |
| Mạng và cấu hình QR | 8/8 | Chọn IP LAN, CIDR, đổi mạng, chặn IP ngoài dải, giả header IP và giới hạn yêu cầu |
| TypeScript API và web | Đạt | `npm run typecheck` |
| Flutter analyzer | Đạt | `flutter analyze` |
| Build API | Đạt | `npm run build:api` |
| Build web production | Đạt | `npm run build:web` |
| Build APK | Đạt | `flutter build apk --debug -t lib/main_staff.dart` |

Lệnh chạy lại:

```powershell
# Tại thư mục gốc SmartRes
node --test scripts/local-config.test.mjs scripts/customer-network.test.mjs
npm run typecheck
npm run build:api
npm run build:web

# Tại apps/api
npx tsx --test scripts/staff.integration.test.ts scripts/customer-security.integration.test.ts scripts/menu-management.integration.test.ts scripts/management-overview.integration.test.ts

# Tại smartresapp
flutter test --reporter expanded
flutter analyze
flutter build apk --debug -t lib/main_staff.dart
```

Kiểm thử backend tạo database tạm và dọn sau khi chạy; không tạo đơn hay hóa đơn thử vào database nhà hàng. Bài HTTP mạng bị sandbox chặn loopback `EACCES` ở lần đầu; chạy lại với quyền kết nối local thì đạt cả 8/8, không cần sửa code.

## Kiểm tra hệ thống đang chạy

Ban đầu cả ba cổng 4000, 4010 và 3000 không có máy chủ (`ECONNREFUSED`). Đã khởi động bằng `npm run dev:customer` và `npm --workspace apps/api run dev:staff`.

- `http://127.0.0.1:4000/api/health`: HTTP 200, backend nhân viên kết nối MySQL.
- `http://127.0.0.1:4010/api/health`: HTTP 200.
- `http://127.0.0.1:3000/order/A01`: HTTP 200.
- Đăng nhập thực tế cả bốn role manager/staff/kitchen/cashier: thành công.
- API báo cáo quản lý: manager nhận 200; staff/kitchen/cashier nhận 403; không đăng nhập nhận 401.
- Báo cáo tháng 10/2026: doanh thu **697.000 đồng**, **4 hóa đơn**, trung bình **174.250 đồng/hóa đơn**. Đã kiểm tra tổng doanh thu theo ngày bằng tổng doanh thu kỳ.
- Vận hành tại thời điểm kiểm tra: 8 bàn, 7 bàn trống, 1 bàn đang phục vụ với 10 khách; tạm tính chưa thu **224.000 đồng**, không cộng vào doanh thu đã thanh toán.
- QR đã được tạo lại theo địa chỉ LAN hiện tại `http://192.168.1.15:3000`, mạng khách được phép `192.168.1.0/24`.

## Phạm vi chưa xác nhận

ADB không có thiết bị kết nối. Chưa chạy thao tác trực tiếp trên máy ảo/điện thoại trong lượt này, chưa nghe chuông bằng loa và chưa kiểm tra quét QR từ điện thoại khác. HTTP 200 của trang web xác nhận máy chủ trả trang, không thay thế kiểm thử tương tác trình duyệt. Kiểm thử chuông Flutter xác nhận lời gọi kênh âm thanh bằng mock.

APK đã build ở `smartresapp/build/app/outputs/flutter-apk/app-debug.apk`. Cần bật máy ảo hoặc kết nối điện thoại để cài và kiểm tra giao diện thật. Các kết quả trên là kiểm thử chức năng hiện có, chưa phải đánh giá tải lớn hoặc độ ổn định dài hạn.
