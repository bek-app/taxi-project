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

Web-server mode:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 5050 --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

Сосын браузерден аш: `http://127.0.0.1:5050/`

## Auth login

Single app алдымен login экранын ашады (`Taxi Super App`).
Login бетінде және қолданба ішінде жоғарғы панельде `KZ/RU` тіл ауыстырғыш бар.
Алдымен `register` арқылы тіркелу керек (email, password, role).

## Role switch

`client_app` ішінде экранның жоғарғы оң жағындағы switch арқылы рөлді ауыстыруға болады:

- `Жолаушы/Клиент`
- `Жүргізуші/Водитель`
