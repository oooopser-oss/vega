import 'dotenv/config';
import { spawn } from 'child_process';
import fs from 'fs/promises';
import path from 'path';

/**
 * Планировщик для запуска мониторинга по расписанию
 * Использование: node src/scheduler.js --interval 3600000 (каждый час)
 */

const args = process.argv.slice(2);
const intervalArg = args.find(a => a.startsWith('--interval'));
const interval = intervalArg ? parseInt(intervalArg.split('=')[1]) : 3600000; // По умолчанию каждый час

console.log('═══════════════════════════════════════');
console.log('  Планировщик мониторинга');
console.log('═══════════════════════════════════════\n');

console.log(`Интервал: ${(interval / 60000).toFixed(0)} минут`);
console.log(`Запуск мониторинга каждые ${(interval / 1000).toFixed(0)} сек\n`);

function runMonitor() {
  const timestamp = new Date().toLocaleString('ru-RU');
  console.log(`\n[${timestamp}] Запуск мониторинга...`);

  const monitor = spawn('node', ['src/monitor.js'], {
    stdio: 'inherit',
    cwd: process.cwd(),
  });

  monitor.on('error', (error) => {
    console.error('✗ Ошибка при запуске мониторинга:', error.message);
  });

  monitor.on('exit', (code) => {
    if (code === 0) {
      console.log(`✓ Мониторинг завершён успешно`);
    } else {
      console.error(`✗ Мониторинг завершился с ошибкой (код ${code})`);
    }
  });
}

// Первый запуск сразу
runMonitor();

// Последующие запуски по расписанию
setInterval(() => {
  runMonitor();
}, interval);

console.log('✓ Планировщик активен, ожидание следующего запуска...\n');

// Обработка сигналов завершения
process.on('SIGINT', () => {
  console.log('\n\nПланировщик остановлен');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n\nПланировщик остановлен');
  process.exit(0);
});
