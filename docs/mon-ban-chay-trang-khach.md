# Món bán chạy trên trang khách

Trang khách quét QR hiển thị bảng xếp hạng món bán chạy trong **30 ngày gần nhất**. Dữ liệu được tổng hợp từ snapshot của `cashier_invoices`, tức chỉ từ hóa đơn thu ngân đã chốt. Đơn chưa thanh toán, đơn hủy hoặc món chỉ nằm trong giỏ không được tính.

## Quy tắc xếp hạng

- Cộng số phần của từng `menuItemId` trong hóa đơn đã thanh toán.
- Chỉ hiển thị món vẫn tồn tại và đang bật bán trong thực đơn hiện hành.
- Ưu tiên tổng số phần, sau đó số hóa đơn có món và doanh số gộp trước giảm giá.
- Tên, mô tả, giá và ảnh lấy từ thực đơn hiện hành; snapshot chỉ dùng để thống kê số phần lịch sử.
- API không trả mã hóa đơn, bàn, nhân viên, khách hoặc chi tiết giao dịch.
- Khi 30 ngày chưa có dữ liệu, giao diện dùng nhãn **Gợi ý hôm nay**, không gọi các món dự phòng là bán chạy.

## API và giao diện

- Customer API: `GET /api/popular-items`.
- Qua web/proxy trên điện thoại: `GET /api/customer/popular-items`.
- Kết quả được cache phía trình duyệt/proxy 60 giây và cho phép dùng dữ liệu cũ tối đa 5 phút trong lúc làm mới.
- `apps/api/src/popular-items.ts`: truy vấn và chuẩn hóa dữ liệu tổng hợp.
- `apps/web/app/order/[tableId]/order-experience.tsx`: banner và trạng thái dự phòng.

## Kiểm thử

```powershell
npm --workspace apps/api run test:popular
npm run typecheck
npm run build:api
npm run build:web
```

Integration test tạo database tạm, kiểm tra thứ hạng, giới hạn 30 ngày, món ngừng bán, đơn chưa thanh toán/đơn hủy và endpoint công khai, sau đó xóa database test.
