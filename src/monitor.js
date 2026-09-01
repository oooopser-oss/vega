import 'dotenv/config';
import BrowserManager from './browser.js';
import ScreenshotManager from './screenshot-manager.js';
import config from './config.js';

const SITE_URL = process.env.SITE_URL || 'http://expl.x5.ru';
const LOGIN = process.env.LOGIN;
const PASSWORD = process.env.PASSWORD;

if (!LOGIN || !PASSWORD) {
  console.error('✗ Ошибка: не установлены LOGIN и PASSWORD в .env файле');
  console.error('Скопируйте .env.example в .env и установите учётные данные');
  process.exit(1);
}

async function monitor() {
  const browser = new BrowserManager();
  const screenshotMgr = new ScreenshotManager(config.screenshotDir);

  try {
    console.log('═══════════════════════════════════════');
    console.log('  Мониторинг заявок - Автоматический');
    console.log('═══════════════════════════════════════\n');

    await screenshotMgr.init();
    await browser.createPage();

    // Вход в систему
    await browser.login(SITE_URL, LOGIN, PASSWORD);
    await screenshotMgr.saveLog('✓ Успешная авторизация');

    // Применяем фильтры
    const filters = config.filters;
    await browser.applyFilters(filters);
    await screenshotMgr.saveLog(`✓ Фильтры применены: ${JSON.stringify(filters)}`);

    // Делаем скриншот
    const screenshotPath = await screenshotMgr.getScreenshotPath('requests');
    await browser.takeScreenshot(screenshotPath);

    // Сохраняем метаданные
    await screenshotMgr.saveMetadata(screenshotPath, filters, {
      siteUrl: SITE_URL,
      userAgent: await browser.page.evaluate(() => navigator.userAgent),
    });

    console.log('\n✓ Мониторинг успешно завершён');
    await screenshotMgr.saveLog('✓ Цикл мониторинга завершён успешно');
  } catch (error) {
    console.error('\n✗ Ошибка при мониторинге:', error.message);
    await screenshotMgr.saveLog(`✗ Ошибка: ${error.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

// Запуск
monitor().catch(error => {
  console.error('✗ Критическая ошибка:', error);
  process.exit(1);
});
