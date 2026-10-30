# Bảo vệ gọi món và cấu hình mạng — 30/10/2026

## Luồng hiện tại: chỉ quét QR, không nhập mã

Theo yêu cầu cập nhật của người dùng, đã bỏ hoàn toàn bước nhập mã 6 số và nút cấp mã trong app nhân viên.

1. Khách kết nối Wi-Fi nhà hàng, quét QR trên bàn và vào thẳng thực đơn.
2. Web tự xin phiên gọi món từ backend. Chỉ bàn đã được nhân viên nhận khách (`dining`) mới được cấp phiên để gửi đơn. Bàn chưa mở vẫn xem/chọn món được, nhưng chưa gửi đơn được; sau khi nhân viên mở bàn, web tự thử kết nối lại mỗi 15 giây hoặc khách bấm Thử kết nối lại.
3. Mỗi điện thoại nhận token ngẫu nhiên riêng, gắn với đúng lượt bàn, không cần nhập hoặc nhìn thấy token.
4. Chờ thanh toán thì không nhận thêm đơn. Thu ngân chốt hóa đơn sẽ thu hồi phiên và trả bàn trong cùng transaction.
5. Tab cũ bị thu hồi phiên sẽ không tự tham gia lượt khách kế tiếp. Khách mới quét lại QR sẽ nhận phiên của lượt mới khi bàn được mở.

QR trên bàn cố định theo mã bàn; chỉ cần tạo/in lại khi thay địa chỉ máy chủ.

## Đổi mạng được phép

Sửa `.env.mysql.local` tại thư mục gốc repo. File này riêng cho từng máy, không commit lên Git.

```dotenv
CUSTOMER_ALLOWED_CIDRS=192.168.1.0/24
NEXT_PUBLIC_WEB_URL=
```

Chuyển mạng: đổi thành `CUSTOMER_ALLOWED_CIDRS=192.168.2.0/24`. Cho phép hai mạng: `CUSTOMER_ALLOWED_CIDRS=192.168.1.0/24,192.168.2.0/24`.

`192.168.1.0/24` cho phép dải IPv4 `192.168.1.*`. Dùng `/32` để chỉ cho một địa chỉ cụ thể. Chỉ chấp nhận dải nội bộ `10.*`, `172.16.*` đến `172.31.*`, `192.168.*`. Không cho mở toàn Internet bằng `0.0.0.0/0`.

Để trống thì tự nhận subnet Wi-Fi/Ethernet, bỏ qua VPN và adapter ảo. Khi dùng trong nhà hàng nên điền rõ dải mạng. Loopback trên máy chủ luôn được phép để kiểm tra local.

Sau khi sửa, Ctrl+C terminal đang chạy rồi chạy lại:

```powershell
npm run dev:customer
```

Lệnh tạo lại QR theo IP hiện tại và in dải được phép. Xóa/đổi `NEXT_PUBLIC_WEB_URL` nếu biến này còn địa chỉ mạng cũ. IP trong QR là địa chỉ máy chủ; `CUSTOMER_ALLOWED_CIDRS` là dải IP thiết bị khách. Nếu cổng đang bị dùng thì dừng dịch vụ cũ trước để tránh áp dụng nhầm cấu hình.

## Mức bảo vệ và giới hạn

- Web kiểm tra socket IP thật trước HTTP và WebSocket upgrade, không tin `X-Forwarded-For`/`X-Real-IP` của khách.
- API khách chỉ nghe `127.0.0.1:4010`, thiết bị khách đi qua web 3000 có kiểm tra mạng. Dùng `npm run dev:customer`/`npm run dev:web`; không chạy `next dev` trực tiếp để bỏ qua bộ lọc.
- Chỉ mạng được phép + bàn đang mở mới nhận phiên. Không có PIN nên **người đang trong mạng được phép và biết URL/giữ ảnh QR vẫn có thể gửi đơn vào bàn đang mở**. Phiên không chứng minh người đó đang ngồi đúng bàn. Đây là giới hạn được chấp nhận khi chọn luồng chỉ quét QR.
- Người ở nhà không vào được nếu mạng/router không mở dịch vụ ra ngoài. Không port-forward hoặc mở tunnel công khai/VPN vào web. Proxy/tunnel local làm nguồn kết nối xuất hiện là loopback nên không thể coi nó là bằng chứng khách đang ở nhà hàng.
- Kiểm tra dải IP không xác minh SSID/vị trí vật lý. Muốn phân biệt hai Wi-Fi thì tách subnet/VLAN ở router. Router phải cho Wi-Fi khách truy cập máy chủ TCP 3000 nhưng chặn các mạng khác.
- Token 32 byte ngẫu nhiên, DB chỉ lưu SHA-256. Web giữ token trong sessionStorage theo bàn, không đưa lên URL/QR. Phiên tối đa 8 giờ; nếu hết hạn mà bàn vẫn đang phục vụ, một lần quét mới sẽ tự gia hạn và token cũ hết hiệu lực.
- Giới hạn 20 lần xin phiên/phút theo IP ở web, 10 đơn/phút theo lượt bàn, tối đa 99 phần/dòng. Backend vẫn kiểm tra token/bàn/trạng thái ở từng đơn và yêu cầu thanh toán.
- Không công khai API sửa trạng thái, webhook thanh toán mẫu hoặc socket bếp/quản lý trên Customer API. App vận hành dùng Staff API có đăng nhập.
- Các cột PIN cũ trong database được giữ để tương thích và không mất dữ liệu, nhưng không còn dùng trong luồng gọi món.
- Lần sửa này chưa thay đổi router/Windows Firewall, chưa kiểm tra trực tiếp điện thoại. Bản local dùng HTTP; khi triển khai thật cần HTTPS và cấu hình mạng phù hợp.

## Chạy và kiểm tra

Máy mới làm theo README: cấu hình MySQL, `npm install`, `npm run setup:customer`, rồi `npm run dev:customer`. Chạy backend nhân viên bằng `npm --workspace apps/api run dev:staff`. API tự bổ sung bảng phiên khi khởi động. Sau khi pull cần cập nhật APK/hot restart để app nhân viên bỏ nút cấp mã.

```powershell
node --test scripts/local-config.test.mjs scripts/customer-network.test.mjs
npm --workspace apps/api run test:customer-security
npm --workspace apps/api run test:staff
npm run typecheck
```

Flutter: `flutter test --no-pub`, `flutter analyze --no-pub` trong `smartresapp`. Kiểm thử MySQL dùng database tạm riêng, không tạo đơn trong DB nhà hàng.

## Các phần đã thay đổi

- `scripts/customer-network.mjs`, `customer-web.mjs`: giới hạn mạng có cấu hình, HTTP/WebSocket và tốc độ xin phiên.
- `database/customer-sessions.sql`, `apps/api/src/customer-sessions.ts`: phiên tự cấp, hash token, hết hạn và thu hồi khi thanh toán.
- `apps/api/src/staff-app.ts`: nhận bàn tạo phiên; thanh toán kết thúc phiên. Không còn API/nút xem/cấp PIN.
- `apps/api/src/repositories/order.repository.ts`: xác thực đúng bàn/lượt ăn trong transaction.
- `apps/web/app/order/[tableId]/customer-access.tsx`: tự kết nối phía sau màn hình thực đơn; không có ô nhập mã.
- `smartresapp/lib/staff_page.dart`: bỏ nút và hộp thoại cấp mã.
- Giữ bản sửa trùng mã hóa đơn khi hai lượt cùng bàn thanh toán trong một phút.

Kết quả kiểm thử được cập nhật trong `HUONG_DAN_VA_NHAT_KY_CAC_CHANG.md`.
