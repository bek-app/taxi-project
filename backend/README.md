# Backend (NestJS)

## Run

```bash
cp .env.example .env
npm install
npm run start:dev
```

API: `http://localhost:3000/api`
Swagger: `http://localhost:3000/api/docs`

## Auth (JWT)

Public endpoints:

- `POST /api/auth/register`
- `POST /api/auth/login`
- `GET /api/auth/me` (Bearer token қажет)
- Startup кезінде seed user жасалмайды: бірінші қолданушы `register` арқылы тіркеледі.
- Қауіпсіздік: public `register` арқылы `ADMIN` рөлін ашуға болмайды.

## WebSocket

- Namespace: `/orders`
- Event from server: `order.updated`
- Event from client: `order.subscribe` with payload `{ "orderId": "<uuid>" }`

## Core endpoints

- `GET /api/auth/me`
- `POST /api/orders`
- `POST /api/orders/:orderId/search-driver`
- `PATCH /api/orders/:orderId/status`
- `PATCH /api/drivers/me/location`
- `PATCH /api/drivers/me/availability`

`/api/orders/*` және `/api/drivers/*` endpoint-тері Bearer token талап етеді.
