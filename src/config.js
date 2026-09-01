// Configuration for screenshot monitoring
export const config = {
  // Фильтры по умолчанию
  filters: {
    status: 'all', // 'all', 'new', 'in_progress', 'completed'
    dateRange: 'today', // 'today', 'week', 'month', 'all'
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
  },

  // Задержки
  delays: {
    afterLogin: 2000, // ms
    afterFilter: 1500, // ms
    beforeScreenshot: 1000, // ms
  },
};

export default config;
