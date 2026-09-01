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
      await this.page.waitForTimeout(1000);

      // Кластер (Select2)
      if (filters.clusters && filters.clusters.length > 0) {
        try {
          console.log(`  → Выбор кластера: ${filters.clusters[0]}`);
          const clusterName = filters.clusters[0];

          // Используем JavaScript для работы с Select2
          await this.page.evaluate((name) => {
            const select = document.querySelector('#clusterSelect');
            if (select) {
              // Ищем опцию по тексту
              const option = Array.from(select.options).find(opt => opt.text.includes(name));
              if (option) {
                select.value = option.value;
                // Триггерим change событие для Select2
                select.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
              }
            }
            return false;
          }, clusterName);

          await this.page.waitForTimeout(500);
          console.log(`    ✓ Кластер выбран`);
        } catch (e) {
          console.log(`    ⚠ Ошибка при выборе кластера: ${e.message}`);
        }
      }

      // Тема (Select)
      if (filters.theme && filters.theme.length > 0) {
        try {
          console.log(`  → Выбор темы`);
          const themeName = filters.theme.includes('tech_equipment')
            ? 'Технологическое оборудование'
            : 'Новый концепт';

          await this.page.evaluate((name) => {
            const select = document.querySelector('#theme');
            if (select) {
              const option = Array.from(select.options).find(opt => opt.text.includes(name));
              if (option) {
                select.value = option.value;
                select.dispatchEvent(new Event('change', { bubbles: true }));
                return true;
              }
            }
            return false;
          }, themeName);

          await this.page.waitForTimeout(500);
          console.log(`    ✓ Тема выбрана: ${themeName}`);
        } catch (e) {
          console.log(`    ⚠ Ошибка при выборе темы: ${e.message}`);
        }
      }

      // Дата "От" для задач
      if (filters.dateFrom) {
        try {
          console.log(`  → Дата от: ${filters.dateFrom}`);
          const dateInput = await this.page.$('#dateStartInc');
          if (dateInput) {
            await dateInput.click();
            await this.page.waitForTimeout(300);
            // Очищаем поле
            await this.page.keyboard.press('Control+A');
            await this.page.keyboard.press('Delete');
            // Вводим дату
            await this.page.keyboard.type(filters.dateFrom);
            await this.page.waitForTimeout(300);
            console.log(`    ✓ Дата от установлена`);
          }
        } catch (e) {
          console.log(`    ⚠ Ошибка при установке даты "От": ${e.message}`);
        }
      }

      // Дата "До" для задач
      if (filters.dateTo) {
        try {
          console.log(`  → Дата до: ${filters.dateTo}`);
          const dateInput = await this.page.$('#dateEndInc');
          if (dateInput) {
            await dateInput.click();
            await this.page.waitForTimeout(300);
            // Очищаем поле
            await this.page.keyboard.press('Control+A');
            await this.page.keyboard.press('Delete');
            // Вводим дату
            await this.page.keyboard.type(filters.dateTo);
            await this.page.waitForTimeout(300);
            console.log(`    ✓ Дата до установлена`);
          }
        } catch (e) {
          console.log(`    ⚠ Ошибка при установке даты "До": ${e.message}`);
        }
      }

      // Статус - применяем checkboxes
      if (filters.status && filters.status !== 'all') {
        try {
          if (filters.status === 'in_progress') {
            console.log(`  → Выбор статуса: Выполняется`);
            const checkbox = await this.page.$('#performedCheckbox');
            if (checkbox) {
              await checkbox.click();
              console.log(`    ✓ Статус "Выполняется" выбран`);
            }
          } else if (filters.status === 'planned') {
            console.log(`  → Выбор статуса: Запланирована`);
            const checkbox = await this.page.$('#plannedCheckbox');
            if (checkbox) {
              await checkbox.click();
              console.log(`    ✓ Статус "Запланирована" выбран`);
            }
          }
          await this.page.waitForTimeout(300);
        } catch (e) {
          console.log(`    ⚠ Ошибка при выборе статуса: ${e.message}`);
        }
      }

      console.log(`  → Фильтры применяются автоматически (нет кнопки "Показать")`);

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
