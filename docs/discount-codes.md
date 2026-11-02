# Mã giảm giá SmartRes

Module sử dụng Flutter + Dart và Express + TypeScript + MySQL hiện có. Quản lý mở **Truy cập nhanh → Giảm giá và khuyến mãi → Giảm giá** để tạo/sửa và bật/tắt mã. Thu ngân mở hóa đơn bàn → Giảm giá → Mã giảm giá → nhập mã → Tìm kiếm → Áp dụng → Thanh toán.

## Kết nối và dữ liệu

- Schema: `database/discount-codes.sql`. Chạy `npm run db:discounts --workspace @smartres/api` sau khi cấu hình MySQL của dự án. Backend cũng tự tạo các bảng nếu thiếu khi khởi động.
- `discount_codes`: chương trình, mã duy nhất, chế độ sinh mã, số lượng phát hành/đã dùng, loại và giá trị giảm, trần giảm, đơn tối thiểu, trạng thái, cấu hình lịch và phiên bản sửa.
- `invoice_discount_codes`: mã đang chọn trên hóa đơn chưa thanh toán. Chọn mã không tiêu hao lượt.
- `discount_redemptions`: ghi nhận mã đã dùng theo đơn đầu của hóa đơn, có ràng buộc duy nhất để ngăn ghi nhận hai lần.
- `apps/api/src/discount-codes.ts`: helper `generateDiscountCode`, kiểm tra đầu vào, lịch và điều kiện sử dụng, CRUD và ghi nhận lượt dùng.
- `smartresapp/lib/discount_management_page.dart`: danh sách; form dùng lại lịch của `PromotionFormDialog` trong `promotion_management_page.dart`.
- `invoice_dialog.dart` gọi `StaffApi.searchDiscountCode`, hiển thị tiền giảm do server tính từ hóa đơn thật, sau đó gọi API áp dụng.

## API

Tất cả API yêu cầu `Authorization: Bearer <token>`, với quyền quản lý hoặc thu ngân phù hợp.

| Phương thức | Đường dẫn | Nội dung |
| --- | --- | --- |
| GET | `/api/v1/manager/discounts` | Danh sách mã, số lượt còn lại |
| POST | `/api/v1/manager/discounts` | Tạo mã |
| POST | `/api/v1/manager/discounts/:id` | Sửa, cần thêm `version` |
| POST | `/api/v1/manager/discounts/:id/status` | `{version,isActive}` |
| POST | `/api/v1/cashier/discounts/search` | `{tableId,discountCode}`; trả `{discount}` hoặc `{message}` với lý do |
| POST | `/api/staff/tables/:id/discount` | `{version,mode:"discount_code",code}`; trả hóa đơn đã tính lại |
| POST | `/api/v1/orders/pay` | `{tableId,paymentMethod,version,confirmUnserved?}`; thanh toán và ghi nhận lượt |

Các API quản lý cũng có alias `/api/staff/management/discounts`; tra cứu có alias `/api/staff/tables/:id/discount-code/search`; thanh toán giữ alias `/api/staff/tables/:id/pay` để tương thích ứng dụng hiện tại.

Ví dụ tạo mã:

```json
{
  "discountName": "Tri Ân Khách Hàng",
  "totalQuantity": 100,
  "codeMode": "auto",
  "discountType": "percentage",
  "discountPercent": 20,
  "fixedAmount": null,
  "maxDiscountAmount": 30000,
  "minOrderValue": 100000,
  "isActive": true,
  "isAlwaysActive": false,
  "allDay": false,
  "startTime": "14:00",
  "endTime": "17:00",
  "weekdays": [1,2,3,4,5],
  "startDate": "2026-11-01",
  "endDate": "2026-11-30"
}
```

Kết quả sinh mã `TAKH10020`. Dùng `codeMode:"manual"` kèm `discountCode` để nhập mã riêng. Mã chỉ chứa A–Z, số, `_`, `-`, tối đa 64 ký tự. Với tiền cố định, chọn `discountType:"fixed"`, `fixedAmount`, và `discountPercent:null`. Giá trị phần trăm có tối đa hai chữ số thập phân; dấu thập phân được bỏ khi sinh mã (12.5 → 125). Mã trùng trả 409, không tự thêm hậu tố.

## Quy tắc

Kiểm tra lần lượt: tồn tại/đang bật → lịch → còn lượt → đơn tối thiểu. Lịch dùng giờ Việt Nam GMT+7, T2=1 đến CN=7, ngày đầu/cuối bao gồm cả ngày; khung giờ gồm giờ bắt đầu và loại giờ kết thúc. Khung giờ qua đêm thuộc ngày bắt đầu. Bật 24/7 bỏ điều kiện lịch, vẫn kiểm tra khóa/lượt/đơn tối thiểu.

Không cộng dồn với khuyến mãi, voucher cũ hay phần trăm thủ công. Giảm được làm tròn theo đồng và không vượt tiền món/trần giảm. Tra cứu không tin số tiền từ client. API áp dụng và thanh toán luôn kiểm tra lại; thẻ tra cứu không giữ chỗ lượt sử dụng.

Khi thanh toán, transaction khóa đơn và mã, tính lại hóa đơn, tăng lượt bằng UPDATE có điều kiện, ghi ledger và lưu snapshot hóa đơn. Nếu bước nào lỗi, toàn bộ transaction rollback. Hai hóa đơn cùng dùng lượt cuối chỉ một hóa đơn thanh toán thành công; hóa đơn kia cần bỏ/đổi mã. Các lần đọc và sửa mã không thay đổi snapshot hóa đơn đã thanh toán.

Kiểm thử: `npm run test:discounts --workspace @smartres/api`; `flutter test test/discount_codes_test.dart` trong thư mục `smartresapp`.
