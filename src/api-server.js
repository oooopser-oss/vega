import 'dotenv/config';
import http from 'http';
import { URL } from 'url';
import BrowserManager from './browser.js';
import ScreenshotManager from './screenshot-manager.js';
import TelegramSender from './telegram-sender.js';
import config from './config.js';

const PORT = config.api.port;
const SITE_URL = process.env.SITE_URL || 'http://expl.x5.ru';
const LOGIN = process.env.LOGIN;
const PASSWORD = process.env.PASSWORD;

if (!LOGIN || !PASSWORD) {
  console.error('✗ Ошибка: не установлены LOGIN и PASSWORD в .env файле');
  process.exit(1);
}

// Telegram
const telegram = config.telegram.enabled
  ? new TelegramSender(config.telegram.botToken, config.telegram.chatId)
  : null;

// Парсинг JSON из тела запроса
async function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });
    req.on('end', () => {
      try {
        resolve(body ? JSON.parse(body) : {});
      } catch (e) {
        reject(e);
      }
    });
  });
}

// Основной обработчик
async function handleRequest(req, res) {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;

  // Установка CORS заголовков
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  res.setHeader('Content-Type', 'application/json');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  try {
    // GET /api/health
    if (pathname === '/api/health' && req.method === 'GET') {
      res.writeHead(200);
      res.end(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }));
      return;
    }

    // POST /api/monitor - запуск мониторинга
    if (pathname === '/api/monitor' && req.method === 'POST') {
      const body = await parseBody(req);
      const filters = body.filters || config.filters;

      res.writeHead(202, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ status: 'processing', message: 'Мониторинг запущен' }));

      // Запускаем мониторинг асинхронно
      runMonitoring(filters).catch(err => {
        console.error('✗ Ошибка в API запросе:', err.message);
        if (telegram) {
          telegram.notifyError(err.message);
        }
      });
      return;
    }

    // GET /api/config - показать текущую конфигурацию
    if (pathname === '/api/config' && req.method === 'GET') {
      res.writeHead(200);
      res.end(JSON.stringify({
        filters: config.filters,
        themeOptions: config.themeOptions,
        telegramEnabled: config.telegram.enabled,
      }));
      return;
    }

    // GET /api/screenshots - список скриншотов
    if (pathname === '/api/screenshots' && req.method === 'GET') {
      const screenshotMgr = new ScreenshotManager(config.screenshotDir);
      const screenshots = await screenshotMgr.listScreenshots();
      res.writeHead(200);
      res.end(JSON.stringify({ screenshots: screenshots.slice(0, 20) }));
      return;
    }

    // Не найдено
    res.writeHead(404);
    res.end(JSON.stringify({ error: 'Endpoint not found' }));
  } catch (error) {
    console.error('✗ Ошибка сервера:', error.message);
    res.writeHead(500);
    res.end(JSON.stringify({ error: error.message }));
  }
}

// Функция запуска мониторинга
async function runMonitoring(filters) {
  const browser = new BrowserManager();
  const screenshotMgr = new ScreenshotManager(config.screenshotDir);

  try {
    console.log('\n═══════════════════════════════════════');
    console.log('  Мониторинг (запуск по API)');
    console.log('═══════════════════════════════════════\n');

    await screenshotMgr.init();
    await browser.createPage();

    // Вход
    await browser.login(SITE_URL, LOGIN, PASSWORD);
    await screenshotMgr.saveLog('✓ Авторизация');

    // Фильтры
    await browser.applyFilters(filters);
    await screenshotMgr.saveLog(`✓ Фильтры: ${JSON.stringify(filters)}`);

    // Скриншот
    const screenshotPath = await screenshotMgr.getScreenshotPath('requests');
    await browser.takeScreenshot(screenshotPath);

    // Метаданные
    await screenshotMgr.saveMetadata(screenshotPath, filters, {
      siteUrl: SITE_URL,
    });

    // Отправляем в Telegram если включено
    if (telegram) {
      await telegram.sendScreenshot(screenshotPath, {
        timestamp: new Date().toISOString(),
        filters,
      });
    }

    console.log('✓ Мониторинг завершён успешно\n');
    await screenshotMgr.saveLog('✓ Завершено успешно');
  } catch (error) {
    console.error('✗ Ошибка:', error.message);
    await screenshotMgr.saveLog(`✗ Ошибка: ${error.message}`);
    if (telegram) {
      await telegram.notifyError(error.message);
    }
    throw error;
  } finally {
    await browser.close();
  }
}

// Создаём сервер
const server = http.createServer(handleRequest);

server.listen(PORT, () => {
  console.log('═══════════════════════════════════════');
  console.log('  API Сервер Мониторинга');
  console.log('═══════════════════════════════════════\n');
  console.log(`✓ Сервер запущен на http://localhost:${PORT}`);
  console.log('\nДоступные endpoints:\n');
  console.log(`  GET  /api/health           - Проверка статуса`);
  console.log(`  POST /api/monitor          - Запуск мониторинга`);
  console.log(`  GET  /api/config           - Конфигурация`);
  console.log(`  GET  /api/screenshots      - Список скриншотов`);
  console.log('\nПримеры запросов:\n');
  console.log(`  # Простой запуск мониторинга`);
  console.log(`  curl -X POST http://localhost:${PORT}/api/monitor\n`);
  console.log(`  # С фильтрами`);
  console.log(`  curl -X POST http://localhost:${PORT}/api/monitor \\`);
  console.log(`    -H "Content-Type: application/json" \\`);
  console.log(`    -d '{`);
  console.log(`      "filters": {`);
  console.log(`        "dateFrom": "2024-01-01",`);
  console.log(`        "dateTo": "2024-01-31",`);
  console.log(`        "clusters": ["cluster1"],`);
  console.log(`        "theme": ["tech_equipment"]`);
  console.log(`      }`);
  console.log(`    }'\n`);
});

// Обработка сигналов завершения
process.on('SIGINT', () => {
  console.log('\n\nСервер остановлен');
  server.close();
  process.exit(0);
});
