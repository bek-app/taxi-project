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

Demo users (seed on startup):

- `client@taxi.local / client123`
- `driver@taxi.local / driver123`
- `admin@taxi.local / admin123`

## WebSocket

- Namespace: `/orders`
- Event from server: `order.updated`
- Event from client: `order.subscribe` with payload `{ "orderId": "<uuid>" }`

## Core endpoints

- `GET /api/auth/me`
- `POST /api/orders`
- `POST /api/orders/:orderId/search-driver`
- `PATCH /api/orders/:orderId/status`
- `PATCH /api/drivers/:driverId/location`
- `PATCH /api/drivers/:driverId/availability`

`/api/orders/*` және `/api/drivers/*` endpoint-тері Bearer token талап етеді.
