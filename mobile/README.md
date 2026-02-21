# Mobile Apps (Flutter)

Қазір негізгі frontend бір проектке біріктірілді:

- `client_app` — single app, ішінде `Client/Driver` role switch бар
- `driver_app` — legacy scaffold (міндетті емес)

## Run (single app)

```bash
cd mobile/client_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

## Auth login

Single app алдымен login экранын ашады (`Taxi Auth Login`).

Demo credentials:

- `client@taxi.local / client123`
- `driver@taxi.local / driver123`
- `admin@taxi.local / admin123`

## Role switch

`client_app` ішінде экранның жоғарғы оң жағындағы switch арқылы рөлді ауыстыруға болады:

- `Client`
- `Driver`
