import { chromium } from 'playwright';
import config from './config.js';

export class BrowserManager {
  constructor() {
    this.browser = null;
    this.page = null;
  }

  async launch() {
    const launchOptions = {
      headless: config.browser.headless,
      slowMo: config.browser.slowMo,
    };

    // Используем предустановленный Chromium если доступен (Linux remote environment)
    const isLinux = process.platform === 'linux';
    if (isLinux && process.env.PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD === '1') {
      launchOptions.executablePath = '/opt/pw-browsers/chromium';
      console.log('→ Используется предустановленный Chromium');
    } else if (process.platform === 'win32') {
      console.log('→ Используется Playwright Chromium для Windows');
    }

    this.browser = await chromium.launch(launchOptions);
    console.log('✓ Браузер запущен');
    return this.browser;
  }

  async createPage() {
    if (!this.browser) {
      await this.launch();
    }
    this.page = await this.browser.newPage();
    this.page.setViewportSize({ width: 1920, height: 1080 });
    console.log('✓ Страница создана (1920x1080)');
    return this.page;
  }

  async login(url, login, password) {
    if (!this.page) {
      await this.createPage();
    }

    try {
      console.log(`\n→ Переход на ${url}`);
      await this.page.goto(url, { waitUntil: 'networkidle', timeout: 30000 });
      console.log('✓ Страница загружена');

      // Ждём видимости login поля
      await this.page.waitForSelector(config.selectors.loginInput, { timeout: 10000 });
      console.log('✓ Форма входа найдена');

      // Вводим логин
      await this.page.fill(config.selectors.loginInput, login);
      console.log('✓ Логин введён');

      // Вводим пароль
      await this.page.fill(config.selectors.passwordInput, password);
      console.log('✓ Пароль введён');

      // Нажимаем кнопку входа
      await this.page.click(config.selectors.submitButton);
      console.log('✓ Кнопка входа нажата');

      // Ждём загрузки после входа
      await this.page.waitForNavigation({ waitUntil: 'networkidle', timeout: 30000 }).catch(() => {});
      await this.page.waitForTimeout(config.delays.afterLogin);
      console.log('✓ Успешно вошли в систему');

      return true;
    } catch (error) {
      console.error('✗ Ошибка при входе:', error.message);
      throw error;
    }
  }

  async applyFilters(filters) {
    if (!this.page) {
      throw new Error('Страница не инициализирована');
    }

    try {
      console.log(`\n→ Применение фильтров`);

      // Дата "От"
      if (filters.dateFrom) {
        try {
          await this.page.fill(config.selectors.dateFromInput, filters.dateFrom, { force: true });
          console.log(`  ✓ Дата от: ${filters.dateFrom}`);
        } catch (e) {
          console.log(`  ⚠ Не удалось установить дату "От"`);
        }
      }

      // Дата "До"
      if (filters.dateTo) {
        try {
          await this.page.fill(config.selectors.dateToInput, filters.dateTo, { force: true });
          console.log(`  ✓ Дата до: ${filters.dateTo}`);
        } catch (e) {
          console.log(`  ⚠ Не удалось установить дату "До"`);
        }
      }

      // Дата решения (план) - от
      if (filters.planDateFrom) {
        try {
          await this.page.fill(config.selectors.planDateFromInput, filters.planDateFrom, { force: true });
          console.log(`  ✓ Дата решения (план) от: ${filters.planDateFrom}`);
        } catch (e) {
          console.log(`  ⚠ Не удалось установить дату решения "От"`);
        }
      }

      // Дата решения (план) - до
      if (filters.planDateTo) {
        try {
          await this.page.fill(config.selectors.planDateToInput, filters.planDateTo, { force: true });
          console.log(`  ✓ Дата решения (план) до: ${filters.planDateTo}`);
        } catch (e) {
          console.log(`  ⚠ Не удалось установить дату решения "До"`);
        }
      }

      // Кластеры (input с множественным выбором или select)
      if (filters.clusters && filters.clusters.length > 0) {
        try {
          const clusterInput = await this.page.$(config.selectors.clusterSelect);
          if (clusterInput) {
            // Попытка заполнить как текстовое поле (для multi-select)
            await this.page.fill(config.selectors.clusterSelect, filters.clusters[0]);
            // Ждём автодополнения и выбора
            await this.page.waitForTimeout(500);
            // Нажимаем на первый результат если появился
            const firstOption = await this.page.$('[role="option"]');
            if (firstOption) await firstOption.click();
            console.log(`  ✓ Кластеры: ${filters.clusters.join(', ')}`);
          }
        } catch (e) {
          console.log(`  ⚠ Не удалось применить фильтр по кластерам`);
        }
      }

      // Тема обращения
      if (filters.theme && filters.theme.length > 0) {
        try {
          // Основная тема
          const themeMainInput = await this.page.$(config.selectors.themeMainSelect);
          if (themeMainInput) {
            // Для "Технологическое оборудование" или "Новый концепт"
            const themeName = filters.theme.includes('tech_equipment')
              ? 'Технологическое оборудование'
              : 'Новый концепт';

            await this.page.fill(config.selectors.themeMainSelect, themeName);
            await this.page.waitForTimeout(500);

            const firstOption = await this.page.$('[role="option"]');
            if (firstOption) await firstOption.click();
            console.log(`  ✓ Тема: ${themeName}`);
          }
        } catch (e) {
          console.log(`  ⚠ Не удалось применить фильтр по теме`);
        }
      }

      // Статус (toggle switches)
      if (filters.status && filters.status !== 'all') {
        try {
          if (filters.status === 'in_progress') {
            const toggle = await this.page.$(config.selectors.statusInProgressToggle);
            if (toggle && !(await toggle.isChecked())) {
              await toggle.click();
            }
            console.log(`  ✓ Статус: Выполняется`);
          } else if (filters.status === 'planned') {
            const toggle = await this.page.$(config.selectors.statusPlannedToggle);
            if (toggle && !(await toggle.isChecked())) {
              await toggle.click();
            }
            console.log(`  ✓ Статус: Запланирована`);
          }
        } catch (e) {
          console.log(`  ⚠ Не удалось применить фильтр по статусу`);
        }
      }

      // Нажимаем кнопку "Применить фильтры"
      try {
        await this.page.click(config.selectors.applyFiltersButton);
        console.log('  ✓ Кнопка "Применить" нажата');
      } catch (e) {
        console.log(`  ⚠ Не удалось нажать кнопку применить`);
      }

      // Ждём обновления контента
      await this.page.waitForTimeout(config.delays.afterFilter);
      console.log('✓ Фильтры применены');

      return true;
    } catch (error) {
      console.error('✗ Ошибка при применении фильтров:', error.message);
      throw error;
    }
  }

  async hideExpiredTasks() {
    if (!this.page) {
      throw new Error('Страница не инициализирована');
    }

    try {
      // Пытаемся найти и скрыть просроченные элементы (красные заявки)
      // Скрываем элементы с классом или атрибутом, указывающим на просрочку
      await this.page.evaluate(() => {
        // Ищем строки таблицы с красным цветом текста (Выполняется - просрочено)
        const rows = document.querySelectorAll('table tr, [role="row"]');
        rows.forEach(row => {
          const text = row.textContent;
          // Если строка содержит "Выполняется" И выделена красным (проверяем стили)
          const style = window.getComputedStyle(row);
          const color = style.color;

          // Красный цвет обычно имеет высокое значение R компоненты
          if (text.includes('Выполняется') && color.includes('rgb')) {
            // Проверяем красный цвет
            const rgbMatch = color.match(/rgb\((\d+),\s*(\d+),\s*(\d+)\)/);
            if (rgbMatch) {
              const [_, r, g, b] = rgbMatch.map(Number);
              // Если красный компонент выше 200 и другие низкие - это красный цвет
              if (r > 150 && g < 100 && b < 100) {
                row.style.display = 'none';
              }
            }
          }
        });
      });

      console.log('✓ Просроченные заявки скрыты');
      return true;
    } catch (error) {
      console.log(`⚠ Не удалось скрыть просроченные заявки: ${error.message}`);
      return false;
    }
  }

  async takeScreenshot(filename, options = {}) {
    if (!this.page) {
      throw new Error('Страница не инициализирована');
    }

    try {
      const excludeExpired = options.excludeExpired !== false; // По умолчанию true

      // Скрываем просроченные заявки если нужно
      if (excludeExpired) {
        await this.hideExpiredTasks();
      }

      await this.page.waitForTimeout(config.delays.beforeScreenshot);

      await this.page.screenshot({
        path: filename,
        fullPage: config.screenshot.fullPage,
        type: 'png',
      });

      console.log(`✓ Скриншот сохранён: ${filename}`);
      return filename;
    } catch (error) {
      console.error('✗ Ошибка при сохранении скриншота:', error.message);
      throw error;
    }
  }

  async close() {
    if (this.page) {
      await this.page.close();
      console.log('✓ Страница закрыта');
    }
    if (this.browser) {
      await this.browser.close();
      console.log('✓ Браузер закрыт');
    }
  }
}

export default BrowserManager;
