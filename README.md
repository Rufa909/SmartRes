# SmartRes

## Menu khách và món bán chạy

Trang khách quét QR đã có ảnh món tối ưu cho điện thoại và khu món bán chạy lấy từ
hóa đơn đã thanh toán trong 30 ngày gần nhất. Khi chưa đủ dữ liệu, giao diện dùng
nhãn gợi ý thay vì hiển thị thứ hạng giả. Xem [cách tính món bán chạy](docs/mon-ban-chay-trang-khach.md).

Trang khách có chatbot tư vấn món từ thực đơn đang bán; khách có thể hỏi giá/khẩu vị
và thêm gợi ý vào giỏ để tự xem lại trước khi gọi. Xem [hướng dẫn chatbot](docs/chatbot-tu-van-mon.md).

Nhân viên cũng có **Trợ lý chọn món** trong màn gọi món cho bàn. Trợ lý dùng số khách,
menu đang bán và các món đã có trong giỏ để gợi ý; nhân viên có thể thêm gợi ý thẳng
vào giỏ trước khi gửi bếp. API này yêu cầu đăng nhập role `staff` hoặc `manager` và
tự chuyển sang chế độ rule-based khi AI service chưa chạy.

Quản lý có thể cấu hình khẩu phần/giá riêng và món thêm/phụ thu theo từng món (ví dụ chỉ có Nhỏ/Vừa, thêm phô mai).
Món cũ tự dùng một cỡ Tiêu chuẩn theo giá hiện tại; xem [hướng dẫn quản lý thực đơn](docs/quan-ly-thuc-don.md).

Khách cũng có thể mở **Đơn của tôi** để theo dõi món và tiến độ bếp trong lượt bàn
hiện tại. Xem [hướng dẫn đơn khách](docs/don-cua-toi-trang-khach.md).

## Tổng quan và doanh thu

Tài khoản quản lý đã có dashboard doanh thu thực thu từ hóa đơn đã thanh toán,
lọc khoảng ngày theo giờ Việt Nam, biểu đồ, món bán chạy, phương thức thanh toán
và trạng thái vận hành hiện tại. Xem [hướng dẫn tổng quan/doanh thu](docs/tong-quan-va-doanh-thu-quan-ly.md).

## Quản lý thực đơn

App Flutter đã có màn hình riêng cho tài khoản `manager`: thêm/sửa món, giá, mô tả,
link ảnh, danh mục và còn bán/hết món. API kiểm tra quyền và lưu dữ liệu vào MySQL.
Xem [hướng dẫn quản lý thực đơn](docs/quan-ly-thuc-don.md) để cập nhật database/APK
và dùng tài khoản quản lý. Các phần quản lý bàn và tài khoản sẽ làm tiếp.

## Bảo vệ QR và chọn mạng Wi-Fi được phép

Khách kết nối Wi-Fi và **quét QR để vào thẳng thực đơn, không nhập mã 6 số**.
Khi quét QR của bàn trống, hệ thống tự mở lượt phục vụ mới; bàn đang chờ thanh toán
vẫn bị khóa. Thanh toán xong thì phiên cũ hết hiệu lực. Người trong mạng được phép
và biết URL/QR có thể tự mở bàn trống, nên cần giới hạn mạng được phép.

Sửa `.env.mysql.local` để chọn mạng, ví dụ `CUSTOMER_ALLOWED_CIDRS=192.168.1.0/24`;
đổi mạng thì sửa dải IP và khởi động lại `npm run dev:customer`. Xem hướng dẫn đầy đủ
tại [Bảo vệ gọi món và cấu hình mạng](docs/bao-ve-goi-mon-va-cau-hinh-mang.md).

Smart Restaurant & Self-Service Ordering System.

Du an duoc thiet lap theo de tai: khach hang quet QR tai ban de goi mon tren web, bep nhan don real-time qua KDS, thu ngan/chu quan quan ly ban, giao dich, menu va bao cao. He thong tach thanh 3 khoi chinh:

- `apps/web`: Next.js, React, TypeScript, Tailwind CSS cho Customer Web App, KDS va Management Dashboard.
- `apps/api`: Node.js, Express, TypeScript, REST API, Socket.io, kien truc MVC + Dependency Injection co ban.
- `apps/ai-service`: Python FastAPI cho chatbot boc tach yeu cau goi mon va goi y upsell.

Ha tang phu tro:

- MySQL luu menu, ban, don hang, thanh toan, nhan vien.
- Redis quan ly phien ban, cache va kenh message real-time.
- SEPay/VietQR duoc chuan bi o lop payment service de tich hop that.

## Cai dat tren may moi

```powershell
Copy-Item .env.example .env
npm install
```

Mở `.env`, điền đúng `MYSQL_USER` và `MYSQL_PASSWORD` của MySQL trên máy. Sau đó
khởi tạo database dùng chung cho app nhân viên và trang khách, đồng thời tạo QR theo
IP LAN của máy đang chạy:

```powershell
npm run setup:customer
```

Mỗi máy clone repository phải tự chạy bước này. Không dùng ảnh QR được tạo trên máy
khác vì ảnh đó chứa IP LAN của máy đã tạo.

Nếu đã có `.env.mysql.local`, file này được ưu tiên hơn `.env` cho cả API, setup
database và tạo QR. Kiểm tra cấu hình trong file này trước khi chạy; database dùng
chung cho app nhân viên và khách phải là `smartres_staff`. Không gửi mật khẩu lên Git.

## Sau khi pull code mới

```powershell
npm install
npm run setup:customer
npm run dev:customer
```

Setup bổ sung bảng/cột còn thiếu và dữ liệu khởi tạo, không xóa đơn hiện có. Nếu
chưa từng cấu hình máy, làm bước sao chép `.env.example` ở trên trước. Máy cần cài
Node.js/npm và MySQL đang chạy; pull Git không tự cài các phần mềm này.

Mã nguồn script trong `scripts/` được commit chung cho nhóm. Ảnh trong
`apps/web/public/qr/` được tạo riêng và đã đưa vào `.gitignore`, giống cấu hình riêng
trong `tools/`. Khi pull lần đầu commit gỡ QR khỏi Git, chạy lại `npm run dev:customer`
để tạo lại ảnh. Mỗi lần chạy lệnh này, QR được cập nhật theo IP hiện tại.

## Chạy trang khách và QR bàn

Chạy một lệnh tại thư mục gốc:

```powershell
npm run dev:customer
```

Lệnh này tạo lại QR theo IP hiện tại rồi chạy đồng thời Customer API và web. Chờ khi
Next.js báo `Ready`, sau đó mở URL được in ra trong `apps/web/public/qr/index.html`
hoặc quét ảnh QR mới. Máy tính và điện thoại phải cùng Wi-Fi.

Terminal sẽ in link `http://<IP-máy>:3000/qr/index.html` để xem/in bộ QR. Script ưu
tiên Wi-Fi và bỏ qua Radmin VPN/adapter ảo. Nếu máy có nhiều mạng hoặc dùng domain,
đặt `NEXT_PUBLIC_WEB_URL=http://<IP-hoặc-domain>:3000` trong `.env.mysql.local`.
Để trống biến này nếu muốn tự nhận IP. QR đã in trước khi IP đổi cần in lại.

Chạy riêng API nhân viên khi cần xem đơn bên app: `npm --workspace apps/api run dev:staff`.
Trên Android emulator vẫn cần nối cổng 4000 bằng ADB như hướng dẫn app hiện có.

Mặc định:

- Web: http://localhost:3000
- Customer API: http://localhost:4010
- Staff API: http://localhost:4000
- AI service: http://localhost:8000/docs
- MySQL: localhost:3306
- Redis: localhost:6379

Nếu Safari mở trang nhưng cứ chờ, kiểm tra terminal phải có cả hai dòng dịch vụ:

- `SmartRes Customer API listening on port 4010`
- `Next.js ... Ready`

Thử trực tiếp `http://<IP-máy-tính>:3000/api/customer/menu`. Nếu URL này không trả
JSON thì Customer API/MySQL chưa sẵn sàng. Nếu máy tính mở được nhưng điện thoại
không mở được, cho phép TCP 3000 trong Windows Firewall (profile Private) và kiểm tra
router không bật AP/client isolation.

## Chạy bằng Docker

Docker Compose hiện là cấu hình hạ tầng tham khảo. Luồng QR phát triển được kiểm tra
bằng các lệnh local ở trên.

## Chay tung service khi phat trien

```bash
cd apps/web
npm install
npm run dev
```

```bash
cd apps/api
npm install
npm run dev
```

```bash
cd apps/ai-service
python -m venv .venv
.venv\Scripts\activate
pip install -e .
uvicorn app.main:app --reload --port 8000
```

## Tai lieu

Xem [docs/architecture.md](docs/architecture.md) de nam kien truc, module, luong du lieu va roadmap trien khai.

