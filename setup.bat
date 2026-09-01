@echo off
chcp 65001 >nul
REM Установка и настройка приложения мониторинга
REM Запустите этот файл один раз для установки

echo.
echo ═══════════════════════════════════════
echo  Установка приложения мониторинга
echo ═══════════════════════════════════════
echo.

REM Проверяем Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo ✗ Node.js не установлен!
    echo Скачайте и установите Node.js: https://nodejs.org/
    pause
    exit /b 1
)
echo ✓ Node.js найден

REM Переходим в ветку
echo.
echo → Переключение на ветку claude/auto-website-screenshots-mwv26z...
git checkout claude/auto-website-screenshots-mwv26z
if errorlevel 1 (
    echo ✗ Не удалось переключиться на ветку
    pause
    exit /b 1
)
echo ✓ Ветка переключена

REM Устанавливаем зависимости
echo.
echo → Установка зависимостей npm...
call npm install
if errorlevel 1 (
    echo ✗ Ошибка при установке зависимостей
    pause
    exit /b 1
)
echo ✓ Зависимости установлены

REM Создаём .env файл
echo.
echo → Создание файла конфигурации (.env)...
(
    echo SITE_URL=http://expl.x5.ru
    echo LOGIN=sk_vega2013
    echo PASSWORD=Sk_vega2013S
    echo SCREENSHOT_DIR=./screenshots
    echo HEADLESS=true
    echo DEBUG=false
    echo TELEGRAM_ENABLED=false
    echo MAX_ENABLED=false
    echo API_PORT=3000
) > .env
echo ✓ Файл .env создан

echo.
echo ═══════════════════════════════════════
echo  ✓ Установка завершена!
echo ═══════════════════════════════════════
echo.
echo Теперь запустите один из файлов:
echo.
echo  Все кластеры:
echo   • run-all.bat           - все кластеры, все темы
echo   • run-all-tech.bat      - все кластеры (технологическое)
echo   • run-all-concept.bat   - все кластеры (новый концепт)
echo.
echo  Кластер 46:
echo   • run-c46-tech.bat      - кластер 46 (технологическое)
echo   • run-c46-concept.bat   - кластер 46 (новый концепт)
echo.
echo  Кластер 49:
echo   • run-c49-tech.bat      - кластер 49 (технологическое)
echo   • run-c49-concept.bat   - кластер 49 (новый концепт)
echo.
echo  Кластер 51:
echo   • run-c51-tech.bat      - кластер 51 (технологическое)
echo   • run-c51-concept.bat   - кластер 51 (новый концепт)
echo.
pause
