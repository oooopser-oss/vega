#!/usr/bin/env node

/**
 * Запуск мониторинга для всех профилей подряд
 * Использование: node src/run-all-profiles.js
 */

import 'dotenv/config';
import { spawn } from 'child_process';
import { listProfiles } from './profiles.js';

const profiles = listProfiles();

console.log('═══════════════════════════════════════');
console.log('  Запуск мониторинга для всех профилей');
console.log('═══════════════════════════════════════\n');

console.log(`Будет запущено ${profiles.length} профилей:\n`);
profiles.forEach((p, i) => {
  console.log(`  ${i + 1}. ${p.name}`);
});

console.log('\n─────────────────────────────────────\n');

async function runProfile(profileId) {
  return new Promise((resolve) => {
    const timestamp = new Date().toLocaleString('ru-RU');
    console.log(`\n[${timestamp}] Запуск профиля: ${profileId}`);

    const child = spawn('node', ['src/cli.js', '--profile', profileId], {
      stdio: 'inherit',
      cwd: process.cwd(),
    });

    child.on('exit', (code) => {
      if (code === 0) {
        console.log(`✓ Профиль "${profileId}" завершён успешно\n`);
      } else {
        console.log(`✗ Профиль "${profileId}" завершился с ошибкой\n`);
      }
      resolve(code === 0);
    });
  });
}

async function main() {
  const results = {};

  for (const profile of profiles) {
    results[profile.id] = await runProfile(profile.id);
    // Пауза между запусками
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  // Итоговый отчёт
  console.log('\n═══════════════════════════════════════');
  console.log('  Итоговый отчёт');
  console.log('═══════════════════════════════════════\n');

  const successful = Object.values(results).filter(r => r).length;
  const failed = profiles.length - successful;

  console.log(`✓ Успешно: ${successful}`);
  console.log(`✗ Ошибок: ${failed}`);
  console.log(`Всего: ${profiles.length}`);

  if (failed > 0) {
    console.log('\nПрофили с ошибками:');
    Object.entries(results)
      .filter(([_, success]) => !success)
      .forEach(([id, _]) => {
        console.log(`  - ${id}`);
      });
  }

  console.log(`\nВремя завершения: ${new Date().toLocaleString('ru-RU')}\n`);

  process.exit(failed > 0 ? 1 : 0);
}

main().catch(error => {
  console.error('✗ Ошибка:', error);
  process.exit(1);
});
