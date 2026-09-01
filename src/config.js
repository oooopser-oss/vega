// Configuration for screenshot monitoring
export const config = {
  // Фильтры по умолчанию
  filters: {
    dateFrom: null,      // YYYY-MM-DD или null (без фильтра)
    dateTo: null,        // YYYY-MM-DD или null (без фильтра)
    clusters: [],        // ['cluster1', 'cluster2'] или []
    theme: [],           // ['tech_equipment', 'new_concept'] или []
    status: 'all',       // 'all', 'new', 'in_progress', 'completed'
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

    // Фильтры
    dateFromInput: 'input[name="date_from"], input[placeholder*="От"]',
    dateToInput: 'input[name="date_to"], input[placeholder*="До"]',
    clustersSelect: 'select[name="clusters"], [data-filter="clusters"]',
    themeSelect: 'select[name="theme"], [data-filter="theme"]',
    statusSelect: 'select[name="status"], [data-filter="status"]',
    applyFiltersButton: 'button:has-text("Применить"), button[type="submit"]',
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
