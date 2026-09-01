import fetch from 'node-fetch';
import fs from 'fs/promises';
import path from 'path';
import config from './config.js';

/**
 * Max.ru (VK Max) интеграция для отправки скриншотов в группу
 * Документация: https://max.ru/
 */

export class MaxSender {
  constructor(accessToken, chatId) {
    this.accessToken = accessToken;
    this.chatId = chatId;
    // Max может использовать VK API или собственный API
    this.apiUrl = 'https://api.max.ru/v1';
  }

  async sendScreenshot(screenshotPath, metadata = {}) {
    if (!this.accessToken || !this.chatId) {
      console.log('⚠ Max.ru не настроен, скриншот не отправлен');
      return false;
    }

    try {
      console.log(`\n→ Отправка скриншота в Max.ru...`);

      // Проверяем файл
      const stats = await fs.stat(screenshotPath);
      if (!stats.isFile()) {
        throw new Error('Файл скриншота не найден');
      }

      const fileBuffer = await fs.readFile(screenshotPath);

      // Формируем текст сообщения
      let message = '📸 Мониторинг заявок\n\n';
      message += `🕐 ${new Date(metadata.timestamp).toLocaleString('ru-RU')}\n`;

      if (metadata.filters) {
        message += '\n📋 Фильтры:\n';
        if (metadata.filters.dateFrom || metadata.filters.dateTo) {
          message += `📅 Период: ${metadata.filters.dateFrom || '---'} до ${metadata.filters.dateTo || '---'}\n`;
        }
        if (metadata.filters.clusters && metadata.filters.clusters.length > 0) {
          message += `🏢 Кластеры: ${metadata.filters.clusters.join(', ')}\n`;
        }
        if (metadata.filters.theme && metadata.filters.theme.length > 0) {
          message += `💭 Тема: ${metadata.filters.theme.join(', ')}\n`;
        }
      }

      // Отправляем скриншот
      // ВАЖНО: Замените код ниже на корректный вызов Max API после уточнения
      return await this.sendViaMaxApi(fileBuffer, message);
    } catch (error) {
      console.error(`✗ Ошибка при отправке в Max: ${error.message}`);
      return false;
    }
  }

  async sendViaMaxApi(fileBuffer, message) {
    // Вариант 1: Если Max использует VK API (VKontakte)
    try {
      const formData = new FormData();
      formData.append('access_token', this.accessToken);
      formData.append('peer_id', this.chatId);
      formData.append('message', message);
      formData.append('attachment', new Blob([fileBuffer], { type: 'image/png' }), 'screenshot.png');

      const response = await fetch('https://api.vk.com/method/messages.send', {
        method: 'POST',
        body: formData,
      });

      const result = await response.json();

      if (result.error) {
        throw new Error(`VK API ошибка: ${result.error.error_msg}`);
      }

      console.log(`✓ Скриншот отправлен в Max (сообщение ID: ${result.response})`);
      return true;
    } catch (error) {
      console.error(`✗ Ошибка API: ${error.message}`);
      return false;
    }
  }

  async sendMessage(text) {
    if (!this.accessToken || !this.chatId) {
      return false;
    }

    try {
      const formData = new FormData();
      formData.append('access_token', this.accessToken);
      formData.append('peer_id', this.chatId);
      formData.append('message', text);
      formData.append('v', '5.131');

      const response = await fetch('https://api.vk.com/method/messages.send', {
        method: 'POST',
        body: formData,
      });

      const result = await response.json();

      if (result.error) {
        throw new Error(`VK API ошибка: ${result.error.error_msg}`);
      }

      return true;
    } catch (error) {
      console.error(`✗ Ошибка при отправке сообщения: ${error.message}`);
      return false;
    }
  }

  async notifyError(errorMessage) {
    const text = `❌ Ошибка мониторинга\n\n${errorMessage}\n\nВремя: ${new Date().toLocaleString('ru-RU')}`;
    return this.sendMessage(text);
  }
}

export default MaxSender;
