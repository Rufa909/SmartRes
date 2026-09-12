# Kien Truc SmartRes

## 1. Muc tieu

SmartRes la he sinh thai nha hang tu phuc vu thong minh. He thong giam thao tac thu cong trong quy trinh goi mon, dong bo don hang thoi gian thuc voi bep va thu ngan, dong thoi ung dung AI de ho tro chon mon va upsell.

## 2. Cac ung dung

### Customer Web App

- Khach quet Dynamic Table QR de mo web app theo `tableId`.
- Xem menu, loc danh muc, tuy bien size/topping/ghi chu.
- Chatbot nhan ngon ngu tu nhien va de xuat gio hang.
- Goi mon va chon thanh toan VietQR/SEPay hoac tien mat.

### Kitchen Display System

- Nhan don moi qua Socket.io.
- Hien thi mon theo trang thai: preparing, cooking, completed.
- Phat am thanh thong bao khi co don moi.
- Co hook de ket noi kitchen printer.

### Management Dashboard

- So do ban real-time: available, dining, waiting_payment.
- Quan ly menu, danh muc, nhan vien.
- Theo doi giao dich SEPay, xac nhan tien mat.
- Bao cao doanh thu nhanh theo ngay.

## 3. Backend Node.js

`apps/api` dung Express + TypeScript theo MVC co ban:

- `controllers`: nhan request, validate input can ban, tra response.
- `services`: chua business logic.
- `repositories`: truy cap database.
- `routes`: khai bao REST endpoint.
- `sockets`: quan ly Socket.io event.
- `container`: Dependency Injection thu cong, du de mo rong ma khong phu thuoc framework nang.

REST API du kien:

- `GET /api/health`
- `GET /api/menu`
- `POST /api/orders`
- `PATCH /api/orders/:id/status`
- `POST /api/payments/sepay/webhook`

Socket event du kien:

- `order.created`
- `order.status_updated`
- `table.status_updated`
- `payment.confirmed`

## 4. AI Service FastAPI

`apps/ai-service` tach rieng de de tich hop LLM:

- `POST /chatbot/parse-order`: boc tach cau nhap cua khach thanh cac item goi mon.
- `POST /upsell/suggest`: goi y mon an kem/combo dua tren gio hang hien tai.

Ban dau service tra ket qua rule-based de phat trien offline. Khi co API key LLM, thay logic trong `services/chatbot.py` va `services/upsell.py`.

## 5. Database

MySQL gom cac bang nen:

- `tables`: ban nha hang va QR token.
- `categories`, `menu_items`, `menu_item_options`: menu va tuy bien mon.
- `orders`, `order_items`: don hang va chi tiet mon.
- `payments`: giao dich SEPay/tien mat.
- `staff_users`: nhan vien, thu ngan, quan ly.

## 6. Luong goi mon

1. Khach quet QR, frontend doc `tableId`.
2. Frontend goi `GET /api/menu`.
3. Khach them mon hoac chat voi AI.
4. Frontend gui `POST /api/orders`.
5. API luu MySQL, cap nhat trang thai ban, emit `order.created`.
6. KDS nhan don moi real-time.
7. Bep cap nhat trang thai mon/don, API emit `order.status_updated`.
8. Thu ngan theo doi thanh toan, SEPay webhook xac nhan giao dich.

## 7. Roadmap gan

- Ket noi repository voi MySQL that bang `mysql2`.
- Them auth JWT cho staff.
- Them giao dien CRUD menu va floor plan.
- Tich hop webhook SEPay that.
- Thay AI rule-based bang LLM API.
- Them test cho service va API route quan trong.

