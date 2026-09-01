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
    submitButton: 'button[type="submit"]',
    contentArea: 'main, [role="main"], .content',

    // Фильтры на сайте expl.x5.ru (используем ID)
    // Вкладки
    typeTasksTab: 'button:contains("Задачи")',
    typeEstimatesTab: 'button.contractor-estimate-btn',

    // Select2 элементы с фильтрами
    clusterSelect: '#clusterSelect',           // Кластер
    divisionSelect: '#divisionSelect',         // Дивизион
    locationSelect: '#locationSelect',        // Местонахождение
    themeSelect: '#theme',                     // Тема обращения
    incidentTypeSelect: '#smhoSelect',         // Тип инцидента

    // Категория (иерархия)
    categoryLevel1: '#catlvl1',
    categoryLevel2: '#catlvl2',
    categoryLevel3: '#catlvl3',
    categoryLevel4: '#catlvl4',

    // Дата создания (для задач)
    dateFromInput: '#dateStartInc',            // Дата от
    dateToInput: '#dateEndInc',                // Дата до

    // Дата для смет
    dateFromEstInput: '#dateStartEst',         // Дата от смет
    dateToEstInput: '#dateEndEst',             // Дата до смет

    // Статус задачи (checkboxes)
    statusPerformedCheckbox: '#performedCheckbox',      // Выполняется
    statusResolvedCheckbox: '#resolvedCheckbox',        // Решена
    statusAppointedCheckbox: '#appointedCheckbox',      // На проверке
    statusClosedCheckbox: '#closedCheckbox',            // Закрыта
    statusCanceledCheckbox: '#canceledCheckbox',        // Отменена
    statusPlannedCheckbox: '#plannedCheckbox',          // Запланирована

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
