// Configuration for screenshot monitoring
export const config = {
  // Фильтры по умолчанию
  filters: {
    dateFrom: null,            // YYYY-MM-DD или null (без фильтра) - дата создания
    dateTo: null,              // YYYY-MM-DD или null (без фильтра) - дата создания
    planDateFrom: null,        // YYYY-MM-DD или null - дата решения (план)
    planDateTo: null,          // YYYY-MM-DD или null - дата решения (план)
    clusters: [],              // ['cluster1', 'cluster2'] или []
    theme: [],                 // ['tech_equipment', 'new_concept'] или []
    status: 'all',             // 'all', 'new', 'in_progress', 'completed'
    excludeExpired: true,      // Исключить просроченные заявки (выделены красным)
  },

  // Возможные темы обращений
  themeOptions: {
    tech_equipment: 'Технологическое оборудование',
    new_concept: 'Новый концепт',
  },

  // Настройки скриншотов
  screenshot: {
    fullPage: true,
    quality: 100,
    timeout: 30000, // ms
  },

  // Настройки браузера
  browser: {
    headless: process.env.HEADLESS !== 'false',
    slowMo: process.env.DEBUG === 'true' ? 1000 : 0,
  },

  // Папка для скриншотов
  screenshotDir: process.env.SCREENSHOT_DIR || './screenshots',

  // Адреса элементов на странице (селекторы)
  selectors: {
    loginInput: 'input[type="text"][placeholder*="логин"], input[name="login"]',
    passwordInput: 'input[type="password"]',
    submitButton: 'button[type="submit"], button:has-text("Вход")',
    contentArea: 'main, [role="main"], .content',

    // Фильтры на сайте expl.x5.ru
    // Тип сущности (вкладки)
    typeTasksTab: 'button:has-text("Задачи")',
    typeEstimatesTab: 'button:has-text("Сметы")',

    // Тип инцидента (выпадающий список)
    incidentTypeSelect: 'select[placeholder*="Выберите тип инцидента"], [data-filter="incident_type"]',

    // Статус задачи (toggle switches)
    statusInProgressToggle: 'input[name="status_in_progress"], [data-status="in_progress"]',
    statusPlannedToggle: 'input[name="status_planned"], [data-status="planned"]',

    // Дивизион
    divisionSelect: 'input[placeholder*="Выберите дивизион"], [data-filter="division"]',

    // Кластер
    clusterSelect: 'input[placeholder*="Кластер"], [data-filter="cluster"]',

    // Местонахождение объекта
    locationSelect: 'select[placeholder*="Выберите местонахождение"], [data-filter="location"]',

    // Тема обращения (основная)
    themeMainSelect: 'input[placeholder*="Технологическое"], [data-filter="theme_main"]',

    // Тема обращения (категория)
    themeCategorySelect: 'select[placeholder*="Выберите категорию"], [data-filter="theme_category"]',

    // Дата создания (от)
    dateFromInput: 'input[placeholder*="От"], input[name="date_from"], [data-filter="date_from"]',

    // Дата создания (до)
    dateToInput: 'input[placeholder*="До"], input[name="date_to"], [data-filter="date_to"]',

    // Дата решения (план) - от
    planDateFromInput: 'input[placeholder*="План от"], input[name="plan_date_from"], [data-filter="plan_date_from"]',

    // Дата решения (план) - до
    planDateToInput: 'input[placeholder*="План до"], input[name="plan_date_to"], [data-filter="plan_date_to"]',

    // Кнопка применить фильтры
    applyFiltersButton: 'button:has-text("Применить"), button:has-text("Поиск"), button[type="submit"]',

    // Просроченные заявки (красные элементы) - для скрытия на скриншоте
    expiredTasksSelector: '.expired, [data-status="expired"], .overdue, [class*="expired"], [style*="red"]',
  },

  // Задержки
  delays: {
    afterLogin: 2000,      // ms
    afterFilter: 1500,     // ms
    beforeScreenshot: 1000, // ms
  },

  // Отправка скриншотов в Telegram
  telegram: {
    enabled: process.env.TELEGRAM_ENABLED === 'true',
    botToken: process.env.TELEGRAM_BOT_TOKEN || '',
    chatId: process.env.TELEGRAM_CHAT_ID || '',
  },

  // Отправка скриншотов в Max.ru
  max: {
    enabled: process.env.MAX_ENABLED === 'true',
    accessToken: process.env.MAX_ACCESS_TOKEN || '',
    chatId: process.env.MAX_CHAT_ID || '',
  },

  // HTTP API для запуска "по требованию"
  api: {
    port: process.env.API_PORT || 3000,
  },
};

export default config;
