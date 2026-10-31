# Chặng quản lý thực đơn — 31/10/2026

## Đã làm

Quản lý đăng nhập app Flutter sẽ vào màn hình **Quản lý · SmartRes**. Chọn **Quản lý thực đơn** để thêm/sửa món, đổi giá, danh mục, mô tả, link ảnh và trạng thái còn bán/hết món. Từ trang quản lý cũng có thể mở vận hành bàn, bếp và thu ngân với cùng phiên đăng nhập.

Luồng: **Đăng nhập quản lý → Quản lý thực đơn → tìm/lọc món → thêm/sửa hoặc bật/tắt bán → lưu MySQL → cập nhật menu khách/nhân viên**.

## Cách dùng

1. Cập nhật APK hoặc hot restart Flutter, đăng nhập tài khoản vai trò `manager`. Tài khoản demo local hiện có: `quanly / QuanLy@123`.
2. Chọn **Quản lý thực đơn**. Ô tìm kiếm hỗ trợ tiếng Việt không dấu; có lọc còn bán/hết món và danh mục.
3. **Thêm danh mục**: bấm biểu tượng thư mục có dấu cộng, nhập tên và thứ tự. Để sửa, chọn danh mục trong bộ lọc rồi bấm biểu tượng bút bên cạnh.
4. **Thêm món**: bấm nút Thêm món, nhập tên, danh mục, giá nguyên theo đồng, mô tả, biểu tượng và link ảnh tùy chọn, rồi bấm Lưu món. Nếu chưa có danh mục thì cần tạo danh mục trước.
5. **Sửa món**: bấm biểu tượng bút trên thẻ món. Có thể sửa tên/giá/mô tả/danh mục/ảnh. Giá hợp lệ từ 0 đến 999.999.999 đồng, không dùng dấu chấm phân cách khi nhập.
6. **Hết món**: tắt công tắc Đang bán trên thẻ. Bật lại khi món sẵn sàng. Backend chặn gọi món đã hết kể cả khách/nhân viên còn đang giữ menu cũ.

## Ảnh và đồng bộ

- Ảnh dùng URL `http/https`, có xem trước và biểu tượng/ảnh dự phòng khi tải lỗi. Để trống để bỏ ảnh. Chưa có chức năng chọn/upload ảnh từ thư viện điện thoại.
- Link ảnh phải truy cập được từ thiết bị xem menu; link `localhost` trên máy tính không dùng chung được với điện thoại. Backend chỉ lưu URL, không tải hộ ảnh hay lưu nội dung từ link bên ngoài.
- Menu web khách tải lại mỗi 10 giây hoặc khi quay lại tab, danh mục lấy từ MySQL thay vì danh sách cố định. Giỏ chưa gửi cập nhật giá khi nhận menu mới; nếu có món hết bán hoặc mất kết nối thì báo kiểm tra lại trước khi gửi.
- Snapshot nhân viên tự cập nhật như trước; màn gọi món lấy dữ liệu khi mở. Nếu đang giữ giỏ cũ, backend vẫn lấy giá thật và từ chối món hết bán. Ảnh mới được dùng trong menu khách và lưới gọi món nhân viên.
- Đổi tên/giá món không thay đổi tên/đơn giá đã lưu trên các dòng đơn hàng cũ. Không xóa cứng món/danh mục trong chặng này để giữ liên kết lịch sử.

## Phân quyền, xung đột và nhật ký

- API kiểm tra vai trò `manager`. Không token trả 401; nhân viên, bếp, thu ngân gọi API quản lý trả 403, kể cả gọi trực tiếp bằng công cụ HTTP.
- Món/danh mục có `version`. Hai thiết bị cùng sửa bản cũ chỉ một yêu cầu được ghi; yêu cầu còn lại nhận 409. Khi gặp thông báo dữ liệu thay đổi, quay về danh sách, bấm tải lại rồi mở sửa từ bản mới.
- Lỗi khi lưu giữ nguyên form để người dùng sửa/thử lại. Lỗi tải có Thử lại; dữ liệu cũ không được dùng để bật/tắt hay mở sửa khi có lỗi.
- Mỗi lần tạo/sửa/bật tắt thành công ghi bảng `menu_audit`: người thao tác, loại thao tác, dữ liệu trước/sau, thời điểm. Chưa có màn hình xem nhật ký này trong app; nhật ký phát triển/hướng dẫn nằm ở file Markdown chung.

## API

| API | Công dụng |
| --- | --- |
| `GET /api/staff/management/menu` | Danh sách toàn bộ món và danh mục |
| `POST /api/staff/management/menu` | Thêm món |
| `POST /api/staff/management/menu/:id` | Sửa món, bắt buộc version |
| `POST /api/staff/management/menu/:id/availability` | Đổi còn bán/hết món, bắt buộc version |
| `POST /api/staff/management/categories` | Thêm danh mục |
| `POST /api/staff/management/categories/:id` | Sửa tên/thứ tự, bắt buộc version |

## Database, chạy và cập nhật

Migration bổ sung `menu_items.image_url`, version cho món/danh mục và bảng `menu_audit`. Chạy lặp an toàn, không xóa dữ liệu. API nhân viên và khách đều gọi migration khi khởi động. Máy hiện tại đã chạy migration thành công trên `smartres_staff`.

Sau khi pull:

```powershell
npm install
npm --workspace apps/api run db:customer
npm --workspace apps/api run dev:staff
```

Chạy web/API khách ở terminal khác: `npm run dev:customer`. App Flutter:

```powershell
cd smartresapp
flutter run -d emulator-5554 -t lib/main_staff.dart
```

Hoặc build APK bằng `flutter build apk --debug -t lib/main_staff.dart --no-pub`. APK mới đã build thành công tại `smartresapp/build/app/outputs/flutter-apk/app-debug.apk`. Máy ảo hiện chưa bật nên chưa cài bản mới trong lượt này.

## Kiểm chứng

- TypeScript backend/web đạt, Flutter analyzer không có vấn đề.
- Flutter 35/35 bài đạt, bao gồm mở quản lý thực đơn, tìm món, bật/tắt, kiểm tra giá, form món/danh mục và giữ dữ liệu khi lưu lỗi.
- Test MySQL `test:menu` đạt: migration từ schema cũ/lặp lại, kiểm tra toàn bộ API với các role, tên trùng, giá/ảnh không hợp lệ, danh mục không tồn tại, hai yêu cầu đồng thời, giá đơn cũ, chặn món hết bán, nhật ký và dữ liệu sau khởi động lại API.
- Các test hồi quy `test:staff`, `test:customer-security` đều đạt trong database tạm riêng.
- Đăng nhập thật tài khoản quản lý local và đọc API quản lý thành công: 6 món, 3 danh mục. Không tạo món, sửa giá hay tạo đơn mẫu vào database thật trong lượt kiểm chứng này.

Các file chính: `apps/api/src/menu-management.ts`, `menu-storage.ts`, `staff-app.ts`; `database/menu-management.sql`; `smartresapp/lib/menu_management_page.dart`, `manager_page.dart`; `apps/web/app/order/[tableId]/order-experience.tsx`.

Phần tổng quan và báo cáo doanh thu đã được bổ sung ở chặng kế tiếp: xem [Tổng quan và doanh thu quản lý](tong-quan-va-doanh-thu-quan-ly.md). Quản lý bàn và quản lý tài khoản vẫn là các chặng tiếp theo.
