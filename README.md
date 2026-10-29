# SmartRes

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

## Chạy trang khách và QR bàn

Chạy một lệnh tại thư mục gốc:

```powershell
npm run dev:customer
```

Lệnh này tạo lại QR theo IP hiện tại rồi chạy đồng thời Customer API và web. Chờ khi
Next.js báo `Ready`, sau đó mở URL được in ra trong `apps/web/public/qr/index.html`
hoặc quét ảnh QR mới. Máy tính và điện thoại phải cùng Wi-Fi.

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

