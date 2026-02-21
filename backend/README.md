# Backend (NestJS)

## Run

```bash
cp .env.example .env
npm install
npm run start:dev
```

API: `http://localhost:3000/api`
Swagger: `http://localhost:3000/api/docs`

## WebSocket

- Namespace: `/orders`
- Event from server: `order.updated`
- Event from client: `order.subscribe` with payload `{ "orderId": "<uuid>" }`

## Core endpoints

- `POST /api/orders`
- `POST /api/orders/:orderId/search-driver`
- `PATCH /api/orders/:orderId/status`
- `PATCH /api/drivers/:driverId/location`
- `PATCH /api/drivers/:driverId/availability`
