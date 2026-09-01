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

      // Жидаем загрузки страницы и появления фильтров
      await this.page.waitForTimeout(1000);

      // Кластеры - ОСНОВНОЙ ФИЛЬТР
      if (filters.clusters && filters.clusters.length > 0) {
        try {
          console.log(`  → Выбор кластера: ${filters.clusters[0]}`);

          // Ищем input поле для кластера и кликаем на него
          const clusterInputs = [
            'input[placeholder*="Кластер"]',
            'input[data-filter="cluster"]',
            'input[placeholder*="кластер"]',
            'input:has-text("Кластер")',
          ];

          let found = false;
          for (const selector of clusterInputs) {
            const element = await this.page.$(selector);
            if (element) {
              await element.click();
              await this.page.waitForTimeout(300);
              // Вводим название кластера
              await this.page.keyboard.type(filters.clusters[0]);
              await this.page.waitForTimeout(500);
              // Ищем и кликаем на опцию в выпадающем списке
              const option = await this.page.evaluate((clusterName) => {
                const options = Array.from(document.querySelectorAll('[role="option"], li, .option, .item'));
                const match = options.find(opt => opt.textContent.includes(clusterName));
                return match ? true : false;
              }, filters.clusters[0]);

              if (option) {
                // Нажимаем Enter или ищем первую опцию
                await this.page.keyboard.press('Enter');
                await this.page.waitForTimeout(300);
                found = true;
                console.log(`    ✓ Кластер выбран`);
                break;
              }
            }
          }

          if (!found) {
            console.log(`    ⚠ Не удалось найти поле кластера`);
          }
        } catch (e) {
          console.log(`    ⚠ Ошибка при выборе кластера: ${e.message}`);
        }
      }

      // Тема обращения
      if (filters.theme && filters.theme.length > 0) {
        try {
          console.log(`  → Выбор темы`);
          const themeName = filters.theme.includes('tech_equipment')
            ? 'Технологическое оборудование'
            : 'Новый концепт';

          const themeInputs = [
            'input[placeholder*="Технологическое"]',
            'input[data-filter="theme_main"]',
            'input[placeholder*="Тема"]',
          ];

          for (const selector of themeInputs) {
            const element = await this.page.$(selector);
            if (element) {
              await element.click();
              await this.page.waitForTimeout(300);
              await this.page.keyboard.type(themeName);
              await this.page.waitForTimeout(500);
              await this.page.keyboard.press('Enter');
              await this.page.waitForTimeout(300);
              console.log(`    ✓ Тема выбрана: ${themeName}`);
              break;
            }
          }
        } catch (e) {
          console.log(`    ⚠ Ошибка при выборе темы: ${e.message}`);
        }
      }

      // Дата "От"
      if (filters.dateFrom) {
        try {
          console.log(`  → Дата от: ${filters.dateFrom}`);
          const dateInputs = [
            'input[placeholder*="От"]',
            'input[name="date_from"]',
            'input[data-filter="date_from"]',
          ];

          for (const selector of dateInputs) {
            const element = await this.page.$(selector);
            if (element) {
              await element.click();
              await this.page.waitForTimeout(300);
              await this.page.keyboard.type(filters.dateFrom);
              await this.page.waitForTimeout(200);
              break;
            }
          }
        } catch (e) {
          console.log(`    ⚠ Ошибка при установке даты "От": ${e.message}`);
        }
      }

      // Дата "До"
      if (filters.dateTo) {
        try {
          console.log(`  → Дата до: ${filters.dateTo}`);
          const dateInputs = [
            'input[placeholder*="До"]',
            'input[name="date_to"]',
            'input[data-filter="date_to"]',
          ];

          for (const selector of dateInputs) {
            const element = await this.page.$(selector);
            if (element) {
              await element.click();
              await this.page.waitForTimeout(300);
              await this.page.keyboard.type(filters.dateTo);
              await this.page.waitForTimeout(200);
              break;
            }
          }
        } catch (e) {
          console.log(`    ⚠ Ошибка при установке даты "До": ${e.message}`);
        }
      }

      // Ищем и нажимаем кнопку "Показать" или "Применить" или "Поиск"
      console.log(`  → Поиск кнопки применения фильтров`);

      let buttonClicked = false;
      try {
        // Ищем кнопку по тексту используя JavaScript
        const found = await this.page.evaluate(() => {
          const buttons = Array.from(document.querySelectorAll('button'));
          const keywords = ['Показать', 'Применить', 'Поиск', 'Обновить', 'Готово', 'Submit'];
          const targetButton = buttons.find(btn =>
            keywords.some(keyword => btn.textContent.includes(keyword))
          );

          if (targetButton) {
            targetButton.click();
            console.log('Button clicked via JS');
            return targetButton.textContent;
          }
          return null;
        });

        if (found) {
          console.log(`    ✓ Кнопка "${found.trim()}" нажата`);
          buttonClicked = true;
        }
      } catch (e) {
        console.log(`    ⚠ Ошибка при поиске кнопки: ${e.message}`);
      }

      // Если JS клик не сработал, пробуем обычные селекторы
      if (!buttonClicked) {
        const simpleSelectors = [
          'button[type="submit"]',
          'button.submit',
          'button.btn-primary',
          '[onclick*="filter"]',
          '[onclick*="search"]',
        ];

        for (const selector of simpleSelectors) {
          try {
            const button = await this.page.$(selector);
            if (button) {
              const isVisible = await button.isVisible().catch(() => false);
              if (isVisible) {
                await button.click();
                console.log(`    ✓ Кнопка нажата`);
                buttonClicked = true;
                break;
              }
            }
          } catch (e) {
            // Игнорируем
          }
        }
      }

      if (!buttonClicked) {
        console.log(`    ⚠ Кнопка применения не найдена, попытаемся продолжить`);
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
