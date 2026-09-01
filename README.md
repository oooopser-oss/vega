# Website Screenshots Monitor

Приложение для автоматического мониторинга заявок на сайте с сохранением скриншотов.

## Возможности

- ✅ Автоматическая авторизация на сайте
- ✅ Применение настраиваемых фильтров
- ✅ Создание скриншотов в высоком разрешении
- ✅ Сохранение метаданных для каждого скриншота
- ✅ Логирование всех операций
- ✅ Организация файлов по датам

## Установка

```bash
npm install
```

## Настройка

1. Скопируйте файл конфигурации:
```bash
cp .env.example .env
```

2. Отредактируйте `.env` с вашими учётными данными:
```
SITE_URL=http://expl.x5.ru
LOGIN=ваш_логин
PASSWORD=ваш_пароль
SCREENSHOT_DIR=./screenshots
HEADLESS=true
DEBUG=false
```

⚠️ **Важно:** Файл `.env` не должен коммититься в git (уже в `.gitignore`)

## Использование

### Однократный запуск мониторинга:
```bash
npm start
```

или

```bash
npm run monitor
```

### Режим разработки (с автоперезагрузкой):
```bash
npm run dev
```

## Структура файлов

```
├── src/
│   ├── config.js              # Конфигурация (селекторы, таймауты, фильтры)
│   ├── browser.js             # Управление браузером (вход, фильтры, скриншоты)
│   ├── screenshot-manager.js  # Управление файлами скриншотов и логами
│   └── monitor.js             # Основной скрипт мониторинга
├── screenshots/               # Папка со скриншотами (создаётся автоматически)
│   └── 2024-09-01/           # Организованы по датам
│       ├── 14-30-45_requests.png
│       ├── 14-30-45_requests.json  # Метаданные
│       └── monitor.log              # Логи дня
├── .env                       # Учётные данные (не коммитится)
├── .env.example               # Пример конфигурации
└── package.json
```

## Настройка фильтров

Отредактируйте `src/config.js`, раздел `config.filters`:

```javascript
filters: {
  status: 'all',      // 'all', 'new', 'in_progress', 'completed'
  dateRange: 'today', // 'today', 'week', 'month', 'all'
}
```

## Настройка селекторов

Если селекторы не работают, обновите их в `src/config.js`:

```javascript
selectors: {
  loginInput: 'input[type="text"]',      // Поле логина
  passwordInput: 'input[type="password"]', // Поле пароля
  submitButton: 'button[type="submit"]',  // Кнопка входа
  contentArea: 'main',                   // Основной контент
}
```

## Автоматизация

Для запуска по расписанию используйте системные инструменты:

### Linux/macOS (cron):
```bash
0 9 * * * cd /path/to/vega && npm run monitor
```

Это запустит мониторинг каждый день в 9:00

### Windows (Task Scheduler):
Создайте задачу, которая запускает:
```
node C:\path\to\vega\src\monitor.js
```

## Результаты

После запуска найдёте:

- **Скриншоты**: `screenshots/YYYY-MM-DD/HH-mm-ss_requests.png`
- **Метаданные**: `screenshots/YYYY-MM-DD/HH-mm-ss_requests.json`
- **Логи**: `screenshots/YYYY-MM-DD/monitor.log`

### Пример метаданных:
```json
{
  "timestamp": "2024-09-01T14:30:45.123Z",
  "screenshot": "14-30-45_requests.png",
  "filters": {
    "status": "all",
    "dateRange": "today"
  },
  "siteUrl": "http://expl.x5.ru"
}
```

## Расширения

Для добавления новых фильтров:

1. Добавьте селектор в `src/config.js`
2. Обновите функцию `applyFilters()` в `src/browser.js`
3. Настройте фильтр в `config.filters`

## Решение проблем

### Ошибка "Страница не загружена"
- Проверьте, что сайт доступен
- Увеличьте `timeout` в `config.screenshot.timeout`

### Ошибка входа
- Проверьте учётные данные в `.env`
- Обновите селекторы в `config.selectors`
- Запустите с `DEBUG=true` для просмотра действий браузера

### Скриншоты с пустым контентом
- Увеличьте `delays.beforeScreenshot` в `config.js`
- Проверьте, загружается ли контент полностью

## Лицензия

MIT
