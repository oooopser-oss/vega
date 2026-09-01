import { chromium } from 'playwright';
import config from './config.js';

export class BrowserManager {
  constructor() {
    this.browser = null;
    this.page = null;
  }

  async launch() {
    this.browser = await chromium.launch({
      headless: config.browser.headless,
      slowMo: config.browser.slowMo,
    });
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
          await this.page.fill(config.selectors.dateFromInput, filters.dateFrom);
          console.log(`  ✓ Дата от: ${filters.dateFrom}`);
        } catch (e) {
          console.log(`  ⚠ Не удалось установить дату "От"`);
        }
      }

      // Дата "До"
      if (filters.dateTo) {
        try {
          await this.page.fill(config.selectors.dateToInput, filters.dateTo);
          console.log(`  ✓ Дата до: ${filters.dateTo}`);
        } catch (e) {
          console.log(`  ⚠ Не удалось установить дату "До"`);
        }
      }

      // Кластеры
      if (filters.clusters && filters.clusters.length > 0) {
        try {
          const clusterSelect = await this.page.$(config.selectors.clustersSelect);
          if (clusterSelect) {
            for (const cluster of filters.clusters) {
              await this.page.selectOption(config.selectors.clustersSelect, cluster);
            }
            console.log(`  ✓ Кластеры: ${filters.clusters.join(', ')}`);
          }
        } catch (e) {
          console.log(`  ⚠ Не удалось применить фильтр по кластерам`);
        }
      }

      // Тема обращения
      if (filters.theme && filters.theme.length > 0) {
        try {
          const themeSelect = await this.page.$(config.selectors.themeSelect);
          if (themeSelect) {
            for (const t of filters.theme) {
              await this.page.selectOption(config.selectors.themeSelect, t);
            }
            console.log(`  ✓ Тема: ${filters.theme.join(', ')}`);
          }
        } catch (e) {
          console.log(`  ⚠ Не удалось применить фильтр по теме`);
        }
      }

      // Статус
      if (filters.status && filters.status !== 'all') {
        try {
          await this.page.selectOption(config.selectors.statusSelect, filters.status);
          console.log(`  ✓ Статус: ${filters.status}`);
        } catch (e) {
          console.log(`  ⚠ Не удалось применить фильтр по статусу`);
        }
      }

      // Нажимаем кнопку "Применить фильтры"
      try {
        const applyBtn = await this.page.$(config.selectors.applyFiltersButton);
        if (applyBtn) {
          await this.page.click(config.selectors.applyFiltersButton);
          console.log('  ✓ Кнопка "Применить" нажата');
        }
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

  async takeScreenshot(filename) {
    if (!this.page) {
      throw new Error('Страница не инициализирована');
    }

    try {
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
