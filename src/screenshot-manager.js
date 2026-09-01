import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

export class ScreenshotManager {
  constructor(baseDir = './screenshots') {
    this.baseDir = baseDir;
  }

  async init() {
    try {
      await fs.mkdir(this.baseDir, { recursive: true });
      console.log(`✓ Директория скриншотов: ${this.baseDir}`);
    } catch (error) {
      console.error('✗ Ошибка при создании директории:', error.message);
      throw error;
    }
  }

  getDateFolder() {
    const now = new Date();
    const year = now.getFullYear();
    const month = String(now.getMonth() + 1).padStart(2, '0');
    const day = String(now.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  getTimestamp() {
    const now = new Date();
    const hours = String(now.getHours()).padStart(2, '0');
    const minutes = String(now.getMinutes()).padStart(2, '0');
    const seconds = String(now.getSeconds()).padStart(2, '0');
    return `${hours}-${minutes}-${seconds}`;
  }

  async getScreenshotPath(name = '') {
    const dateFolder = this.getDateFolder();
    const timestamp = this.getTimestamp();
    const folderPath = path.join(this.baseDir, dateFolder);

    await fs.mkdir(folderPath, { recursive: true });

    const filename = name ? `${timestamp}_${name}.png` : `${timestamp}.png`;
    return path.join(folderPath, filename);
  }

  async saveLog(content) {
    try {
      const dateFolder = this.getDateFolder();
      const logDir = path.join(this.baseDir, dateFolder);
      await fs.mkdir(logDir, { recursive: true });

      const logFile = path.join(logDir, 'monitor.log');
      const timestamp = new Date().toISOString();
      const logEntry = `[${timestamp}] ${content}\n`;

      await fs.appendFile(logFile, logEntry);
    } catch (error) {
      console.error('✗ Ошибка при сохранении лога:', error.message);
    }
  }

  async saveMetadata(screenshotFile, filters, metadata = {}) {
    try {
      const dir = path.dirname(screenshotFile);
      const basename = path.basename(screenshotFile, '.png');
      const metaFile = path.join(dir, `${basename}.json`);

      const data = {
        timestamp: new Date().toISOString(),
        screenshot: path.basename(screenshotFile),
        filters,
        ...metadata,
      };

      await fs.writeFile(metaFile, JSON.stringify(data, null, 2));
      console.log(`✓ Метаданные сохранены: ${metaFile}`);
    } catch (error) {
      console.error('✗ Ошибка при сохранении метаданных:', error.message);
    }
  }

  async listScreenshots() {
    try {
      const files = await fs.readdir(this.baseDir, { recursive: true });
      return files.filter(f => f.endsWith('.png')).sort().reverse();
    } catch (error) {
      console.error('✗ Ошибка при чтении директории:', error.message);
      return [];
    }
  }

  async getLatestScreenshot() {
    const screenshots = await this.listScreenshots();
    if (screenshots.length === 0) return null;
    return path.join(this.baseDir, screenshots[0]);
  }
}

export default ScreenshotManager;
