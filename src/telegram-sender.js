import fetch from 'node-fetch';
import fs from 'fs/promises';
import path from 'path';
import config from './config.js';

export class TelegramSender {
  constructor(botToken, chatId) {
    this.botToken = botToken;
    this.chatId = chatId;
    this.apiUrl = `https://api.telegram.org/bot${botToken}`;
  }

  async sendScreenshot(screenshotPath, metadata = {}) {
    if (!this.botToken || !this.chatId) {
      console.log('⚠ Telegram не настроен, скриншот не отправлен');
      return false;
    }

    try {
      console.log(`\n→ Отправка скриншота в Telegram...`);

      // Проверяем, существует ли файл
      const stats = await fs.stat(screenshotPath);
      if (!stats.isFile()) {
        throw new Error('Файл скриншота не найден');
      }

      // Читаем файл
      const fileBuffer = await fs.readFile(screenshotPath);

      // Формируем подпись
      let caption = '📸 Мониторинг заявок\n\n';
      caption += `🕐 ${new Date(metadata.timestamp).toLocaleString('ru-RU')}\n`;

      if (metadata.filters) {
        caption += '\n📋 Фильтры:\n';
        if (metadata.filters.dateFrom || metadata.filters.dateTo) {
          caption += `📅 Период: ${metadata.filters.dateFrom || '---'} до ${metadata.filters.dateTo || '---'}\n`;
        }
        if (metadata.filters.clusters && metadata.filters.clusters.length > 0) {
          caption += `🏢 Кластеры: ${metadata.filters.clusters.join(', ')}\n`;
        }
        if (metadata.filters.theme && metadata.filters.theme.length > 0) {
          caption += `💭 Тема: ${metadata.filters.theme.join(', ')}\n`;
        }
        if (metadata.filters.status) {
          caption += `✅ Статус: ${metadata.filters.status}\n`;
        }
      }

      // Отправляем фото через FormData
      const formData = new FormData();
      formData.append('chat_id', this.chatId);
      formData.append('photo', new Blob([fileBuffer], { type: 'image/png' }), path.basename(screenshotPath));
      formData.append('caption', caption);
      formData.append('parse_mode', 'HTML');

      const response = await fetch(`${this.apiUrl}/sendPhoto`, {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`Telegram API ошибка: ${error}`);
      }

      const result = await response.json();
      console.log(`✓ Скриншот отправлен в Telegram (ID: ${result.result.message_id})`);
      return true;
    } catch (error) {
      console.error(`✗ Ошибка при отправке в Telegram: ${error.message}`);
      return false;
    }
  }

  async sendMessage(text) {
    if (!this.botToken || !this.chatId) {
      return false;
    }

    try {
      const response = await fetch(`${this.apiUrl}/sendMessage`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          chat_id: this.chatId,
          text: text,
          parse_mode: 'HTML',
        }),
      });

      if (!response.ok) {
        const error = await response.text();
        throw new Error(`Telegram API ошибка: ${error}`);
      }

      return true;
    } catch (error) {
      console.error(`✗ Ошибка при отправке сообщения в Telegram: ${error.message}`);
      return false;
    }
  }

  async notifyError(errorMessage) {
    const text = `❌ <b>Ошибка мониторинга</b>\n\n${errorMessage}\n\nВремя: ${new Date().toLocaleString('ru-RU')}`;
    return this.sendMessage(text);
  }
}

export default TelegramSender;
