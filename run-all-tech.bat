@echo off
chcp 65001 >nul
title Мониторинг - Все кластеры (Технологическое)
echo Все кластеры - Технологическое оборудование
echo Время: %date% %time%
call npm run cli:all-tech
pause
