#!/usr/bin/env node

import 'dotenv/config';
import process from 'process';
import BrowserManager from './browser.js';
import ScreenshotManager from './screenshot-manager.js';
import TelegramSender from './telegram-sender.js';
import MaxSender from './max-sender.js';
import { profiles, getProfile, listProfiles } from './profiles.js';
import config from './config.js';

const SITE_URL = process.env.SITE_URL || 'http://expl.x5.ru';
const LOGIN = process.env.LOGIN;
const PASSWORD = process.env.PASSWORD;

if (!LOGIN || !PASSWORD) {
  console.error('✗ Ошибка: не установлены LOGIN и PASSWORD в .env файле');
  process.exit(1);
}

// Парсинг аргументов командной строки
function parseArgs() {
  const args = process.argv.slice(2);
  const params = {};

  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].substring(2);
      const value = args[i + 1];

      if (value && !value.startsWith('--')) {
        if (key === 'clusters' || key === 'theme') {
          params[key] = value.split(',');
        } else {
          params[key] = value;
        }
        i++;
      } else {
        params[key] = true;
      }
    }
  }

  return params;
}

async function main() {
  const args = parseArgs();

  // Справка
  if (args.help || Object.keys(args).length === 0) {
    const profilesList = listProfiles();
    console.log(`
  📸 CLI Мониторинга Заявок
  ═════════════════════════════

  Использование: node src/cli.js [опции]

  Опции:
    --profile PROFILE     ID профиля (см. ниже)
    --date-from DATE      Дата от (YYYY-MM-DD)
    --date-to DATE        Дата до (YYYY-MM-DD)
    --clusters NAMES      Кластеры (через запятую: cluster1,cluster2)
    --theme THEME         Тема (tech_equipment,new_concept)
    --status STATUS       Статус (all, new, in_progress, completed)
    --send-telegram       Отправить в Telegram
    --list-profiles       Показать все профили
    --help                Справка

  Доступные профили:
  `);

    for (const p of profilesList) {
      console.log(`    ${p.id.padEnd(15)} - ${p.name}`);
    }

    console.log(`
  Примеры:
    # Профиль: Кластер 46 - Технологическое оборудование
    node src/cli.js --profile c46-tech

    # Профиль: Все кластеры - Все темы
    node src/cli.js --profile all

    # С дополнительными фильтрами
    node src/cli.js --profile c46-tech --date-from 2024-09-01 --date-to 2024-09-30

    # С отправкой в Telegram
    node src/cli.js --profile c46-tech --send-telegram

    # Кастомные фильтры (без профиля)
    node src/cli.js --clusters cluster1,cluster2 --theme tech_equipment

    # Все профили
    node src/cli.js --list-profiles
  `);
    if (args.help) process.exit(0);
  }

  // Показать все профили
  if (args['list-profiles']) {
    console.log('\n📋 Доступные профили:\n');
    const profilesList = listProfiles();
    for (const p of profilesList) {
      console.log(`  ${p.id.padEnd(15)} - ${p.name}`);
    }
    console.log('');
    process.exit(0);
  }

  const browser = new BrowserManager();
  const screenshotMgr = new ScreenshotManager(config.screenshotDir);

  try {
    console.log('═══════════════════════════════════════');
    console.log('  Мониторинг заявок - CLI');
    console.log('═══════════════════════════════════════\n');

    await screenshotMgr.init();
    await browser.createPage();

    // Формируем фильтры
    let filters = {
      dateFrom: args['date-from'] || config.filters.dateFrom,
      dateTo: args['date-to'] || config.filters.dateTo,
      clusters: args.clusters || config.filters.clusters,
      theme: args.theme || config.filters.theme,
      status: args.status || config.filters.status,
    };

    // Если задан профиль, используем его фильтры
    if (args.profile) {
      const profile = getProfile(args.profile);
      if (!profile) {
        console.error(`✗ Профиль "${args.profile}" не найден`);
        console.log('Доступные профили:');
        listProfiles().forEach(p => console.log(`  - ${p.id}`));
        process.exit(1);
      }

      console.log(`\n📌 Используется профиль: ${profile.name}\n`);
      filters = {
        ...profile.filters,
        // Перекрываем профиль аргументами командной строки если они переданы
        dateFrom: args['date-from'] || profile.filters.dateFrom,
        dateTo: args['date-to'] || profile.filters.dateTo,
        status: args.status || profile.filters.status,
      };
    }

    console.log('Параметры запуска:\n');
    console.log(`  Сайт: ${SITE_URL}`);
    console.log(`  Фильтры:`);
    console.log(`    • Дата от: ${filters.dateFrom || '(не указана)'}`);
    console.log(`    • Дата до: ${filters.dateTo || '(не указана)'}`);
    console.log(`    • Кластеры: ${filters.clusters.length > 0 ? filters.clusters.join(', ') : '(все)'}`);
    console.log(`    • Тема: ${filters.theme.length > 0 ? filters.theme.join(', ') : '(все)'}`);
    console.log(`    • Статус: ${filters.status}`);
    console.log(`  Telegram: ${args['send-telegram'] ? 'ДА' : 'НЕТ'}\n`);

    // Вход
    await browser.login(SITE_URL, LOGIN, PASSWORD);
    await screenshotMgr.saveLog('✓ Авторизация');

    // Фильтры
    await browser.applyFilters(filters);
    await screenshotMgr.saveLog(`✓ Фильтры применены`);

    // Скриншот
    const screenshotPath = await screenshotMgr.getScreenshotPath('requests');
    await browser.takeScreenshot(screenshotPath);

    // Метаданные
    await screenshotMgr.saveMetadata(screenshotPath, filters, {
      siteUrl: SITE_URL,
      cli: true,
    });

    // Отправляем в Telegram если запрошено
    if (args['send-telegram']) {
      const telegram = new TelegramSender(config.telegram.botToken, config.telegram.chatId);
      await telegram.sendScreenshot(screenshotPath, {
        timestamp: new Date().toISOString(),
        filters,
      });
    }

    // Отправляем в Max если включено
    if (config.max.enabled) {
      const max = new MaxSender(config.max.accessToken, config.max.chatId);
      await max.sendScreenshot(screenshotPath, {
        timestamp: new Date().toISOString(),
        filters,
      });
    }

    console.log('\n✓ Мониторинг завершён успешно');
    await screenshotMgr.saveLog('✓ CLI запуск завершён');
  } catch (error) {
    console.error('\n✗ Ошибка:', error.message);
    await screenshotMgr.saveLog(`✗ Ошибка: ${error.message}`);
    process.exit(1);
  } finally {
    await browser.close();
  }
}

main().catch(error => {
  console.error('✗ Критическая ошибка:', error);
  process.exit(1);
});
