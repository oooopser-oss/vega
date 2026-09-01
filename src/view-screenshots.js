import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

/**
 * Скрипт для просмотра информации о последних скриншотах
 * Использование: node src/view-screenshots.js [--limit 10]
 */

const screenshotDir = './screenshots';
const args = process.argv.slice(2);
const limitArg = args.find(a => a.startsWith('--limit'));
const limit = limitArg ? parseInt(limitArg.split('=')[1]) : 5;

async function viewScreenshots() {
  console.log('═══════════════════════════════════════');
  console.log('  Просмотр скриншотов');
  console.log('═══════════════════════════════════════\n');

  try {
    const files = await fs.readdir(screenshotDir, { recursive: true });
    const screenshots = files
      .filter(f => f.endsWith('.json'))
      .sort()
      .reverse()
      .slice(0, limit);

    if (screenshots.length === 0) {
      console.log('✗ Скриншоты не найдены');
      return;
    }

    console.log(`✓ Найдено последних ${screenshots.length} скриншотов:\n`);

    for (const file of screenshots) {
      const fullPath = path.join(screenshotDir, file);
      const metaContent = await fs.readFile(fullPath, 'utf-8');
      const meta = JSON.parse(metaContent);

      const date = new Date(meta.timestamp);
      const timeStr = date.toLocaleString('ru-RU');
      const screenshotName = meta.screenshot;

      console.log(`📷 ${screenshotName}`);
      console.log(`   Время: ${timeStr}`);
      console.log(`   Фильтры: ${JSON.stringify(meta.filters)}`);
      if (meta.siteUrl) {
        console.log(`   Сайт: ${meta.siteUrl}`);
      }
      console.log('');
    }

    // Общая статистика
    const allScreenshots = files.filter(f => f.endsWith('.json'));
    const dates = [...new Set(screenshots.map(f => f.split('/')[0]))];

    console.log('─────────────────────────────────────');
    console.log(`Всего скриншотов: ${allScreenshots.length}`);
    console.log(`Дней с скриншотами: ${dates.length}`);
  } catch (error) {
    if (error.code === 'ENOENT') {
      console.log('✗ Папка со скриншотами не найдена');
      console.log('Запустите мониторинг для создания скриншотов');
    } else {
      console.error('✗ Ошибка:', error.message);
    }
  }
}

viewScreenshots();
