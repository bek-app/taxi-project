# Mobile Apps (Flutter)

Бұл каталогта екі app-тың бастапқы коды бар:

- `client_app` — жолаушы интерфейсі
- `driver_app` — жүргізуші интерфейсі

## Неге platform файлдары жоқ

Ағымдағы ортада Flutter SDK орнатылмаған. Сондықтан тек бизнес-логикаға керек бастапқы Dart коды берілді.

Flutter орнатылған соң әр app ішінде:

```bash
flutter create .
flutter pub get
flutter run
```

Backend URL override үшін:

```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```
