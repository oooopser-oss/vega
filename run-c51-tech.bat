@echo off
chcp 65001 >nul
title Мониторинг - Кластер 51 (Технологическое)
echo Кластер 51 - Технологическое оборудование
echo Время: %date% %time%
call npm run cli:c51-tech
pause
