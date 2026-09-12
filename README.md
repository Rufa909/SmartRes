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

## Chay bang Docker

```bash
cp .env.example .env
docker compose up --build
```

Mac dinh:

- Web: http://localhost:3000
- API: http://localhost:4000
- AI service: http://localhost:8000/docs
- MySQL: localhost:3306
- Redis: localhost:6379

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

