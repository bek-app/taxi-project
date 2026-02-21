# Taxi MVP Monorepo

Бұл репо `taxi_mvp_flutter_investor_version_FINAL.pdf` нұсқаулығына сай MVP-дің бастапқы қаңқасын береді.

## Құрылым

- `backend/` — NestJS API (Order lifecycle, matchmaking, pricing, WebSocket events)
- `mobile/client_app/` — Flutter single app (`Client/Driver` role switch)
- `mobile/driver_app/` — legacy scaffold (міндетті емес)
- `docker-compose.yml` — PostgreSQL + Redis локал сервисі

## Қамтылған MVP логика

- Order lifecycle:
  - `CREATED -> SEARCHING_DRIVER -> DRIVER_ASSIGNED -> DRIVER_ARRIVING -> IN_PROGRESS -> COMPLETED`
  - `CANCELED` күйіне рұқсат бар
- Redis Geo арқылы жақын жүргізушіні іздеу
- Баға формуласы:
  - `final_price = baseFare + (km * perKm) + (minutes * perMinute)`
- WebSocket арқылы order status оқиғаларын тарату

## 1) Backend іске қосу

Талап: Node.js 20+

```bash
cd backend
cp ../.env.example .env
npm install
npm run start:dev
```

API default: `http://localhost:3000`
Swagger: `http://localhost:3000/api/docs`

Auth:
- `POST /api/auth/login`
- Demo users:
  - `client@taxi.local / client123`
  - `driver@taxi.local / driver123`
  - `admin@taxi.local / admin123`

## 2) Инфрақұрылым сервисі

Талап: Docker

```bash
docker compose up -d
```

## 3) Flutter app-ты бастау (single app)

```bash
cd mobile/client_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

## Келесі фаза

1. Auth/роль (Client/Driver/Admin) енгізу
2. Payments және комиссияны нақты есептеу
3. Multi-city (`city_id`, `zone_id`) қолдауы
4. Order/Geo/Payment microservice-ке бөлу
