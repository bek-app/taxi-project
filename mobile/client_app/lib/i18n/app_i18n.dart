enum AppLang { kz, ru }

extension AppLangX on AppLang {
  String get code {
    switch (this) {
      case AppLang.kz:
        return 'KZ';
      case AppLang.ru:
        return 'RU';
    }
  }
}

class AppI18n {
  const AppI18n(this.lang);

  final AppLang lang;

  static const Map<AppLang, Map<String, String>> _strings = {
    AppLang.kz: {
      'app_title': 'Taxi MVP',
      'workspace': 'Жұмыс аймағы',
      'role_client': 'Жолаушы',
      'role_driver': 'Жүргізуші',
      'role_admin': 'Админ',
      'login_title': 'Taxi Super App',
      'login_subtitle':
          'Нағыз сценарий: тіркелу, кіру, және картада өз орныңды көру.',
      'api_label': 'API',
      'email_label': 'Email',
      'password_label': 'Құпиясөз',
      'confirm_password_label': 'Құпиясөзді растау',
      'register_as_label': 'Рөл',
      'register': 'Тіркелу',
      'registering': 'Тіркеліп жатыр...',
      'auth_switch_to_login': 'Аккаунт бар ма? Кіру',
      'auth_switch_to_register': 'Жаңа аккаунт ашу',
      'password_mismatch': 'Құпиясөздер бірдей емес.',
      'client_only_message': 'Тапсырыс беру үшін CLIENT аккаунтымен кіріңіз.',
      'sign_in': 'Кіру',
      'signing_in': 'Кіріп жатыр...',
      'language': 'Тіл',
      'logout': 'Шығу',
      'profile': 'Профиль',
      'profile_title': 'Профиль деректері',
      'profile_subtitle':
          'Email-ды өзгертіңіз және қажет болса құпиясөзді жаңартыңыз.',
      'refresh_profile': 'Профильді жаңарту',
      'profile_user_id': 'Пайдаланушы ID: {id}',
      'profile_password_section': 'Құпиясөзді ауыстыру',
      'profile_password_hint':
          'Құпиясөзді өзгертпесеңіз, төмендегі өрістерді бос қалдырыңыз.',
      'profile_current_password': 'Ағымдағы құпиясөз',
      'profile_new_password': 'Жаңа құпиясөз',
      'profile_confirm_new_password': 'Жаңа құпиясөзді растау',
      'profile_email_required': 'Email міндетті.',
      'profile_current_password_required':
          'Құпиясөзді ауыстыру үшін ағымдағы құпиясөз қажет.',
      'profile_new_password_min': 'Жаңа құпиясөз кемінде 6 таңба болуы керек.',
      'save_changes': 'Өзгерістерді сақтау',
      'saving_changes': 'Сақталуда...',
      'profile_saved': 'Профиль сәтті жаңартылды.',
      'my_trips': 'Сапарларым',
      'orders_load_failed': 'Сапарларды жүктеу сәтсіз болды.',
      'trips_active': 'Белсенді',
      'trips_history': 'Тарих',
      'trips_summary_total': 'Жалпы сома',
      'trips_summary_active': 'Белсенді сапар',
      'trips_summary_history': 'Тарихтағы сапар',
      'trips_empty_active': 'Белсенді сапарлар жоқ.',
      'trips_empty_history': 'Сапарлар тарихы әзірге бос.',
      'pickup_label': 'Алу нүктесі',
      'dropoff_label': 'Жету нүктесі',
      'refresh_location': 'Геолокацияны жаңарту',
      'locating': 'Орныңыз анықталып жатыр...',
      'location_ready': 'Сіздің орныңыз картада көрсетілді',
      'location_permission_denied':
          'Геолокация рұқсаты жоқ. Браузерден рұқсат беріңіз.',
      'location_service_disabled':
          'Геолокация сервисі өшірілген. Қосып қайта көріңіз.',
      'location_unknown': 'Орныңыз анықталмады',
      'current_city': 'Қазіргі қала: {city}',
      'current_address': 'Ағымдағы адрес: {address}',
      'city_unknown': 'анықталмады',
      'map_tap_hint': 'Картадан нүкте басып destination таңдаңыз.',
      'map_pickup_hint': 'Картадан нүкте басып алу орнын таңдаңыз.',
      'online_drivers_count': 'Online жүргізушілер: {count}',
      'refresh_status': 'Күйді жаңарту',
      'search_pickup': 'Шығу нүктесін іздеу',
      'your_location': 'Сіздің орыныңыз',
      'search_destination': 'Мекенжай іздеу',
      'where_to': 'Қайда барасыз?',
      'signed_as': '{email} аккаунтымен кірді',
      'set_destination': 'Маршрут таңдау',
      'confirm_ride': 'Сапарды растау',
      'tariff': 'Тариф',
      'tariff_economy': 'Эконом',
      'tariff_comfort': 'Комфорт',
      'tariff_business': 'Бизнес',
      'tariff_multiplier': 'x{value} коэффициент',
      'formula_caption':
          'Формула: baseFare + (km * perKm) + (minutes * perMinute)',
      'final_price': 'Қорытынды: {price} KZT',
      'please_wait': 'Күтіңіз...',
      'searching_driver': 'Жүргізуші ізделуде...',
      'waiting_driver_confirmation':
          'Жүргізушіге ұсыныс жіберілді, растауын күтіп тұрмыз...',
      'search_result': 'Іздеу нәтижесі',
      'creating_order': 'Backend ішінде тапсырыс жасалуда...',
      'order_short': 'Тапсырыс: {id} • Күйі: {status}',
      'retry_search': 'Қайта іздеу',
      'cancel': 'Бас тарту',
      'driver_not_found': 'Жүргізуші табылмады. Қайта іздеп көріңіз.',
      'order_canceled_by_client': 'Тапсырысты клиент болдырмады.',
      'order_canceled_by_driver': 'Тапсырысты жүргізуші болдырмады.',
      'order_canceled_by_admin': 'Тапсырысты админ болдырмады.',
      'order_canceled_by_you': 'Тапсырысты сіз болдырмадыңыз.',
      'order_canceled': 'Тапсырыс болдырылды.',
      'active_order_exists':
          'Белсенді тапсырыс бар. Жаңа тапсырыс беру үшін алдымен аяқтаңыз не болдырмаңыз.',
      'active_order_exists_short': 'Белсенді тапсырыс бар',
      'driver_name': 'Aidos K.',
      'car_info': 'Toyota Camry • 001 ABC',
      'order_id': 'Тапсырыс ID: {id}',
      'call': 'Қоңырау',
      'complete_trip': 'Сапарды аяқтау',
      'updating': 'Жаңартылуда...',
      'trip_completed': 'Сапар аяқталды',
      'order_number': 'Тапсырыс: {id}',
      'book_again': 'Қайта тапсырыс беру',
      'driver_workspace': 'Жүргізуші панелі',
      'online_mode': 'Online режим',
      'online_subtitle': 'Redis availability + геолокация жаңарту',
      'current_order': 'Ағымдағы тапсырыс',
      'no_active_order': 'Белсенді тапсырыс жоқ.',
      'orders_list_title': 'Тапсырыстар тізімі',
      'orders_list_empty': 'Тапсырыстар әлі жоқ.',
      'status': 'Күйі: {value}',
      'final_price_label': 'Соңғы баға: {value} KZT',
      'distance_to_pickup': 'Алу нүктесіне дейін: {meters} м',
      'pickup_reached': 'Алу нүктесіне жеттіңіз',
      'pickup_distance_unknown': 'Pickup қашықтығы анықталмады (GPS керек)',
      'pickup_arrival_required':
          'Сапарды бастау үшін алдымен алу нүктесіне жетіңіз',
      'driver_id': 'Driver ID: {value}',
      'loading': 'Жүктелуде...',
      'refresh_orders': 'Тапсырысты жаңарту',
      'accept_ride': 'Сапарды қабылдау',
      'mark_arrived': 'Келдім',
      'set_arriving': 'Жолда деп белгілеу',
      'start_ride': 'Сапарды бастау',
      'complete_ride': 'Сапарды аяқтау',
      'signed_role': '{email} ({role})',
      'status_CREATED': 'Жаңа',
      'status_SEARCHING_DRIVER': 'Жүргізуші ізделуде',
      'status_DRIVER_ASSIGNED': 'Жүргізуші тағайындалды',
      'status_DRIVER_ARRIVING': 'Жүргізуші келе жатыр',
      'status_DRIVER_ARRIVED': 'Жүргізуші келді',
      'status_IN_PROGRESS': 'Сапар жүріп жатыр',
      'status_COMPLETED': 'Аяқталды',
      'status_CANCELED': 'Бас тартылды',
      'invalid_login_response': 'Login жауабы қате.',
      'invalid_register_response': 'Register жауабы қате.',
      'route_calculating': 'Маршрут жолмен есептеліп жатыр...',
      'route_ready': 'Маршрут: {km} км • {min} мин',
      'route_fallback':
          'Маршрут сервисі уақытша қолжетімсіз, тікелей қашықтық қолданылды.',
      'unknown_error': 'Белгісіз қате',
    },
    AppLang.ru: {
      'app_title': 'Taxi MVP',
      'workspace': 'Рабочая область',
      'role_client': 'Клиент',
      'role_driver': 'Водитель',
      'role_admin': 'Админ',
      'login_title': 'Taxi Super App',
      'login_subtitle':
          'Реальный сценарий: регистрация, вход и отображение вашей геолокации на карте.',
      'api_label': 'API',
      'email_label': 'Email',
      'password_label': 'Пароль',
      'confirm_password_label': 'Подтвердите пароль',
      'register_as_label': 'Роль',
      'register': 'Зарегистрироваться',
      'registering': 'Регистрация...',
      'auth_switch_to_login': 'Уже есть аккаунт? Войти',
      'auth_switch_to_register': 'Создать новый аккаунт',
      'password_mismatch': 'Пароли не совпадают.',
      'client_only_message': 'Для заказа поездки войдите как CLIENT.',
      'sign_in': 'Войти',
      'signing_in': 'Вход...',
      'language': 'Язык',
      'logout': 'Выйти',
      'profile': 'Профиль',
      'profile_title': 'Данные профиля',
      'profile_subtitle': 'Измените email и при необходимости обновите пароль.',
      'refresh_profile': 'Обновить профиль',
      'profile_user_id': 'ID пользователя: {id}',
      'profile_password_section': 'Смена пароля',
      'profile_password_hint':
          'Оставьте поля ниже пустыми, если не хотите менять пароль.',
      'profile_current_password': 'Текущий пароль',
      'profile_new_password': 'Новый пароль',
      'profile_confirm_new_password': 'Подтвердите новый пароль',
      'profile_email_required': 'Email обязателен.',
      'profile_current_password_required':
          'Для смены пароля нужен текущий пароль.',
      'profile_new_password_min':
          'Новый пароль должен быть не короче 6 символов.',
      'save_changes': 'Сохранить изменения',
      'saving_changes': 'Сохраняем...',
      'profile_saved': 'Профиль успешно обновлен.',
      'my_trips': 'Мои поездки',
      'orders_load_failed': 'Не удалось загрузить поездки.',
      'trips_active': 'Активные',
      'trips_history': 'История',
      'trips_summary_total': 'Общая сумма',
      'trips_summary_active': 'Активные поездки',
      'trips_summary_history': 'Поездки в истории',
      'trips_empty_active': 'Активных поездок нет.',
      'trips_empty_history': 'История поездок пока пустая.',
      'pickup_label': 'Точка подачи',
      'dropoff_label': 'Точка прибытия',
      'refresh_location': 'Обновить геолокацию',
      'locating': 'Определяем ваше местоположение...',
      'location_ready': 'Ваше местоположение отображено на карте',
      'location_permission_denied':
          'Нет доступа к геолокации. Разрешите доступ в браузере.',
      'location_service_disabled':
          'Сервис геолокации отключен. Включите и повторите.',
      'location_unknown': 'Не удалось определить местоположение',
      'current_city': 'Текущий город: {city}',
      'current_address': 'Текущий адрес: {address}',
      'city_unknown': 'не определен',
      'map_tap_hint': 'Нажмите на карту, чтобы выбрать destination.',
      'map_pickup_hint': 'Нажмите на карту, чтобы выбрать точку подачи.',
      'online_drivers_count': 'Онлайн водителей: {count}',
      'refresh_status': 'Обновить статус',
      'search_pickup': 'Откуда едем?',
      'your_location': 'Ваше местоположение',
      'search_destination': 'Введите адрес',
      'where_to': 'Куда поедем?',
      'signed_as': 'Вход выполнен: {email}',
      'set_destination': 'Выбрать маршрут',
      'confirm_ride': 'Подтвердить поездку',
      'tariff': 'Тариф',
      'tariff_economy': 'Эконом',
      'tariff_comfort': 'Комфорт',
      'tariff_business': 'Бизнес',
      'tariff_multiplier': 'x{value} коэффициент',
      'formula_caption':
          'Формула: baseFare + (km * perKm) + (minutes * perMinute)',
      'final_price': 'Итог: {price} KZT',
      'please_wait': 'Подождите...',
      'searching_driver': 'Ищем водителя...',
      'waiting_driver_confirmation':
          'Предложение отправлено водителю, ожидаем подтверждение...',
      'search_result': 'Результат поиска',
      'creating_order': 'Создаем заказ в backend...',
      'order_short': 'Заказ: {id} • Статус: {status}',
      'retry_search': 'Повторить поиск',
      'cancel': 'Отмена',
      'driver_not_found': 'Водитель не найден. Попробуйте еще раз.',
      'order_canceled_by_client': 'Заказ отменил клиент.',
      'order_canceled_by_driver': 'Заказ отменил водитель.',
      'order_canceled_by_admin': 'Заказ отменил администратор.',
      'order_canceled_by_you': 'Заказ отменили вы.',
      'order_canceled': 'Заказ отменен.',
      'active_order_exists':
          'У вас уже есть активный заказ. Завершите или отмените его перед новым заказом.',
      'active_order_exists_short': 'Есть активный заказ',
      'driver_name': 'Aidos K.',
      'car_info': 'Toyota Camry • 001 ABC',
      'order_id': 'Заказ ID: {id}',
      'call': 'Позвонить',
      'complete_trip': 'Завершить поездку',
      'updating': 'Обновление...',
      'trip_completed': 'Поездка завершена',
      'order_number': 'Заказ: {id}',
      'book_again': 'Заказать снова',
      'driver_workspace': 'Панель водителя',
      'online_mode': 'Онлайн режим',
      'online_subtitle': 'Redis availability + обновление геолокации',
      'current_order': 'Текущий заказ',
      'no_active_order': 'Активных заказов нет.',
      'orders_list_title': 'Список заказов',
      'orders_list_empty': 'Заказов пока нет.',
      'status': 'Статус: {value}',
      'final_price_label': 'Итоговая цена: {value} KZT',
      'distance_to_pickup': 'До точки подачи: {meters} м',
      'pickup_reached': 'Вы прибыли в точку подачи',
      'pickup_distance_unknown':
          'Расстояние до точки подачи неизвестно (нужен GPS)',
      'pickup_arrival_required':
          'Чтобы начать поездку, сначала прибудьте в точку подачи',
      'driver_id': 'Driver ID: {value}',
      'loading': 'Загрузка...',
      'refresh_orders': 'Обновить заказы',
      'accept_ride': 'Принять заказ',
      'mark_arrived': 'Прибыл',
      'set_arriving': 'Отметить: подъезжаю',
      'start_ride': 'Начать поездку',
      'complete_ride': 'Завершить заказ',
      'signed_role': '{email} ({role})',
      'status_CREATED': 'Новый',
      'status_SEARCHING_DRIVER': 'Поиск водителя',
      'status_DRIVER_ASSIGNED': 'Водитель назначен',
      'status_DRIVER_ARRIVING': 'Водитель подъезжает',
      'status_DRIVER_ARRIVED': 'Водитель прибыл',
      'status_IN_PROGRESS': 'Поездка идет',
      'status_COMPLETED': 'Завершено',
      'status_CANCELED': 'Отменено',
      'invalid_login_response': 'Некорректный ответ login.',
      'invalid_register_response': 'Некорректный ответ register.',
      'route_calculating': 'Считаем маршрут по дороге...',
      'route_ready': 'Маршрут: {km} км • {min} мин',
      'route_fallback':
          'Сервис маршрута временно недоступен, используется прямая дистанция.',
      'unknown_error': 'Неизвестная ошибка',
    },
  };

  String t(String key, [Map<String, String> params = const {}]) {
    final fallback = _strings[AppLang.kz]?[key] ?? key;
    final raw = _strings[lang]?[key] ?? fallback;
    var resolved = raw;
    for (final entry in params.entries) {
      resolved = resolved.replaceAll('{${entry.key}}', entry.value);
    }
    return resolved;
  }
}

String localizedOrderStatus(AppLang lang, String status) {
  final i18n = AppI18n(lang);
  switch (status) {
    case 'CREATED':
      return i18n.t('status_CREATED');
    case 'SEARCHING_DRIVER':
      return i18n.t('status_SEARCHING_DRIVER');
    case 'DRIVER_ASSIGNED':
      return i18n.t('status_DRIVER_ASSIGNED');
    case 'DRIVER_ARRIVING':
      return i18n.t('status_DRIVER_ARRIVING');
    case 'DRIVER_ARRIVED':
      return i18n.t('status_DRIVER_ARRIVED');
    case 'IN_PROGRESS':
      return i18n.t('status_IN_PROGRESS');
    case 'COMPLETED':
      return i18n.t('status_COMPLETED');
    case 'CANCELED':
      return i18n.t('status_CANCELED');
    default:
      return status;
  }
}
