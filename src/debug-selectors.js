#!/usr/bin/env node

/**
 * Отладка селекторов - показывает структуру фильтров на сайте
 * Использование: node src/debug-selectors.js
 */

import 'dotenv/config';
import BrowserManager from './browser.js';
import config from './config.js';

const SITE_URL = process.env.SITE_URL || 'http://expl.x5.ru';
const LOGIN = process.env.LOGIN;
const PASSWORD = process.env.PASSWORD;

if (!LOGIN || !PASSWORD) {
  console.error('✗ Ошибка: не установлены LOGIN и PASSWORD в .env файле');
  process.exit(1);
}

async function debugSelectors() {
  const browser = new BrowserManager();

  try {
    console.log('═══════════════════════════════════════');
    console.log('  ОТЛАДКА СЕЛЕКТОРОВ ФИЛЬТРОВ');
    console.log('═══════════════════════════════════════\n');

    await browser.createPage();
    console.log('\n1️⃣ Вход на сайт...');
    await browser.login(SITE_URL, LOGIN, PASSWORD);

    const page = browser.page;

    console.log('\n2️⃣ Поиск всех input полей:\n');
    const inputs = await page.evaluate(() => {
      const elements = document.querySelectorAll('input, select, button');
      const result = [];
      elements.forEach((el, idx) => {
        if (idx < 50) { // Первые 50 элементов
          result.push({
            tag: el.tagName,
            type: el.type || el.getAttribute('role'),
            placeholder: el.placeholder,
            id: el.id,
            name: el.name,
            class: el.className,
            value: el.value,
            text: el.textContent?.substring(0, 50),
          });
        }
      });
      return result;
    });

    console.log('Найденные элементы:');
    inputs.forEach((input, idx) => {
      console.log(`\n${idx + 1}. ${input.tag}${input.type ? ` [${input.type}]` : ''}`);
      if (input.placeholder) console.log(`   placeholder: "${input.placeholder}"`);
      if (input.id) console.log(`   id: "${input.id}"`);
      if (input.name) console.log(`   name: "${input.name}"`);
      if (input.class) console.log(`   class: "${input.class}"`);
      if (input.text) console.log(`   text: "${input.text}"`);
    });

    console.log('\n\n3️⃣ Поиск всех кнопок:\n');
    const buttons = await page.evaluate(() => {
      const elements = document.querySelectorAll('button');
      const result = [];
      elements.forEach((btn, idx) => {
        if (idx < 30) {
          result.push({
            text: btn.textContent?.trim(),
            id: btn.id,
            class: btn.className,
            type: btn.type,
          });
        }
      });
      return result;
    });

    console.log('Кнопки на странице:');
    buttons.forEach((btn, idx) => {
      if (btn.text) {
        console.log(`${idx + 1}. "${btn.text}"`);
        if (btn.class) console.log(`   class: "${btn.class}"`);
        if (btn.id) console.log(`   id: "${btn.id}"`);
      }
    });

    console.log('\n\n4️⃣ Поиск элементов по ключевым словам:\n');
    const keywords = await page.evaluate(() => {
      const result = {};

      // Поиск по тексту
      const texts = ['Кластер', 'Тип', 'Тема', 'Дата', 'Показать', 'Применить', 'Фильтр'];
      texts.forEach(keyword => {
        const elements = Array.from(document.querySelectorAll('*')).filter(el =>
          el.textContent?.includes(keyword) && el.offsetHeight > 0
        ).slice(0, 3);

        if (elements.length > 0) {
          result[keyword] = elements.map(el => ({
            tag: el.tagName,
            class: el.className,
            id: el.id,
            text: el.textContent?.substring(0, 50),
          }));
        }
      });

      return result;
    });

    console.log('Элементы по ключевым словам:');
    Object.entries(keywords).forEach(([keyword, elements]) => {
      console.log(`\n"${keyword}":`);
      elements.forEach((el, idx) => {
        console.log(`  ${idx + 1}. <${el.tag}>`);
        if (el.id) console.log(`     id: "${el.id}"`);
        if (el.class) console.log(`     class: "${el.class}"`);
      });
    });

    console.log('\n\n5️⃣ HTML структура фильтров:\n');
    const html = await page.evaluate(() => {
      // Ищем контейнер фильтров
      const filterContainers = [
        document.querySelector('[data-test*="filter"]'),
        document.querySelector('.filters'),
        document.querySelector('[class*="filter"]'),
        document.querySelector('[class*="Filter"]'),
        document.querySelector('form'),
      ].filter(el => el && el.offsetHeight > 0);

      if (filterContainers.length > 0) {
        return filterContainers[0].outerHTML.substring(0, 2000);
      }
      return 'Контейнер фильтров не найден';
    });

    console.log(html);

    console.log('\n\n═══════════════════════════════════════');
    console.log('✓ Отладка завершена!');
    console.log('═══════════════════════════════════════\n');

  } catch (error) {
    console.error('✗ Ошибка:', error.message);
  } finally {
    await browser.close();
  }
}

debugSelectors();
