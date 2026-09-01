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

### Базовая конфигурация

1. Скопируйте файл конфигурации:
```bash
cp .env.example .env
```

2. Отредактируйте `.env` с вашими учётными данными:
```bash
# Сайт и учётные данные (обязательно)
SITE_URL=http://expl.x5.ru
LOGIN=ваш_логин
PASSWORD=ваш_пароль

# Папка для скриншотов
SCREENSHOT_DIR=./screenshots

# Режимы
HEADLESS=true    # true = без видимого браузера, false = видимый браузер
DEBUG=false      # true = медленное выполнение, видны все действия
```

⚠️ **Важно:** Файл `.env` не должен коммититься в git (уже в `.gitignore`)

### Интеграция с Telegram

Для отправки скриншотов в группу Telegram:

1. Создайте бота через [@BotFather](https://t.me/botfather) в Telegram
2. Создайте группу и добавьте бота в неё
3. Получите ID группы (например, через [@userinfobot](https://t.me/userinfobot))
4. Добавьте в `.env`:

```bash
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
TELEGRAM_CHAT_ID=-123456789
```

### Интеграция с Max.ru (VK Max)

Для отправки скриншотов в группу Max.ru:

1. Получите Access Token через [VK Developer](https://dev.vk.com)
2. Создайте или используйте существующую группу в Max
3. Получите ID группы
4. Добавьте в `.env`:

```bash
MAX_ENABLED=true
MAX_ACCESS_TOKEN=your_access_token
MAX_CHAT_ID=-your_group_id
```

**Подробная инструкция:** [docs/MAX_INTEGRATION.md](docs/MAX_INTEGRATION.md)

### Одновременная отправка в несколько мессенджеров

Включите несколько интеграций в `.env`:

```bash
# Telegram + Max.ru
TELEGRAM_ENABLED=true
TELEGRAM_BOT_TOKEN=...
TELEGRAM_CHAT_ID=...

MAX_ENABLED=true
MAX_ACCESS_TOKEN=...
MAX_CHAT_ID=...
```

Скриншоты будут отправлены в обе группы одновременно.

### Настройка фильтров

Отредактируйте `src/config.js`, раздел `filters`:

```javascript
filters: {
  dateFrom: null,           // Дата от (YYYY-MM-DD)
  dateTo: null,             // Дата до (YYYY-MM-DD)
  clusters: [],             // Кластеры: ['cluster1', 'cluster2']
  theme: [],                // Тема: ['tech_equipment', 'new_concept']
  status: 'all',            // Статус: 'all', 'new', 'in_progress', 'completed'
}
```

Доступные темы:
- `tech_equipment` — Технологическое оборудование
- `new_concept` — Новый концепт

## Использование

### 1️⃣ Основной мониторинг

Однократный запуск с фильтрами из конфига:
```bash
npm run monitor
```

Режим разработки (с автоперезагрузкой):
```bash
npm run monitor:dev
```

### 2️⃣ CLI - Запуск по требованию

Запуск с параметрами через командную строку:

```bash
# Простой запуск
npm run cli

# С фильтрами по дате
npm run cli -- --date-from 2024-09-01 --date-to 2024-09-30

# Фильтр по кластерам и теме
npm run cli -- --clusters cluster1,cluster2 --theme tech_equipment

# С отправкой в Telegram
npm run cli -- --send-telegram

# Все вместе
npm run cli -- \
  --date-from 2024-09-01 \
  --date-to 2024-09-30 \
  --clusters cluster1 \
  --theme tech_equipment \
  --send-telegram

# Справка
npm run cli -- --help
```

### 3️⃣ API Server - Запуск "по требованию" через HTTP

Запуск API сервера:
```bash
npm run api
```

Доступные endpoints:
```bash
# Проверка статуса
curl http://localhost:3000/api/health

# Запуск мониторинга (базовый)
curl -X POST http://localhost:3000/api/monitor

# Запуск с фильтрами
curl -X POST http://localhost:3000/api/monitor \
  -H "Content-Type: application/json" \
  -d '{
    "filters": {
      "dateFrom": "2024-09-01",
      "dateTo": "2024-09-30",
      "clusters": ["cluster1", "cluster2"],
      "theme": ["tech_equipment"]
    }
  }'

# Получить конфигурацию
curl http://localhost:3000/api/config

# Получить список скриншотов
curl http://localhost:3000/api/screenshots
```

### 4️⃣ Планировщик - Автоматические запуски

Запуск мониторинга каждый час:
```bash
npm run scheduler:hourly
```

Запуск каждый день:
```bash
npm run scheduler:daily
```

Или с кастомным интервалом (в миллисекундах):
```bash
npm run scheduler -- --interval=1800000  # Каждые 30 минут
```

### 5️⃣ Просмотр результатов

Просмотр последних скриншотов:
```bash
npm run view

# Показать последние 10 скриншотов
npm run view -- --limit=10
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
