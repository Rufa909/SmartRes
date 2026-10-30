# Kiểm tra truy cập QR trên máy local — 30/10/2026

> Cập nhật sau khi sửa: đã đồng bộ cấu hình, tự chọn IP và tạo lại 8 QR cho `192.168.1.15:3000`. Web/API đã chạy thử, trang QR, trang đặt món A01 và API menu đều trả HTTP 200. Xem README để dùng lệnh chung `npm run dev:customer`. Các mục bên dưới ghi lại trạng thái lúc chẩn đoán ban đầu.

## Kết quả kiểm tra

- Thư mục QR thực tế: `apps/web/public/qr`.
- Trang `index.html` đi kèm bộ QR ghi các URL dạng `http://192.168.2.50:3000/order/A01`.
- Địa chỉ Wi-Fi hiện tại của máy: `192.168.1.15`. Máy cũng có Radmin VPN, vì vậy cần chọn đúng IP Wi-Fi khi tạo QR cho điện thoại trong mạng nhà.
- Tại thời điểm kiểm tra, `netstat` không thấy tiến trình lắng nghe cổng 3000, 4000 hoặc 4010.
- Web được cấu hình chạy trên `0.0.0.0:3000`; Next.js chuyển tiếp `/api/customer/*` sang API khách ở `127.0.0.1:4010`.
- Launcher PowerShell hiện chỉ khởi động API nhân viên `dev:staff`; chưa khởi động web và API khách.
- Log web cũ từng ghi nhận truy cập `/order/A01` trả 200. Log cũ không xác nhận dịch vụ đang chạy hiện tại.

## Nguyên nhân và cách khắc phục

Bộ QR chứa địa chỉ cố định theo máy/mạng lúc tạo. Khi IP của máy thay đổi hoặc dùng QR do thành viên khác tạo, điện thoại sẽ truy cập sai máy. Ngoài ra, cần chạy cả web và API khách.

Từ thư mục `D:\DoAn4\SmartRes`, mở hai terminal:

```powershell
npm run dev:web
```

```powershell
npm run dev:customer-api
```

Sau khi web sẵn sàng, kiểm tra trên máy tính: `http://127.0.0.1:3000/order/A01`. Điện thoại kết nối cùng Wi-Fi thử `http://192.168.1.15:3000/order/A01`. Địa chỉ này chỉ đúng khi máy vẫn giữ IP đã ghi nhận ở trên.

Để tạo lại QR trỏ vào máy này trong PowerShell:

```powershell
$env:NEXT_PUBLIC_WEB_URL = 'http://192.168.1.15:3000'
npm run generate:qr
Remove-Item Env:NEXT_PUBLIC_WEB_URL
```

Script tạo QR hiện đọc cấu hình database từ `.env`, trong khi API ưu tiên `.env.mysql.local`. Nếu tạo QR báo lỗi đăng nhập hoặc thiếu bảng, cần đối chiếu hai cấu hình này; không xóa database để xử lý lỗi truy cập QR.

Nếu máy tính mở được nhưng điện thoại không mở được sau khi chạy web, kiểm tra cùng mạng Wi-Fi, quyền Windows Firewall cho web cổng 3000 và chế độ cô lập thiết bị của router. Chưa kiểm chứng trực tiếp truy cập từ điện thoại hoặc nguyên nhân firewall.

## Phạm vi lần kiểm tra

Chỉ kiểm tra mã nguồn, cấu hình URL, địa chỉ mạng, cổng đang chạy và log hiện có. Chưa đổi QR, chưa khởi động dịch vụ, chưa thay đổi database hoặc firewall, chưa xác nhận một đơn đặt món đầu cuối.
