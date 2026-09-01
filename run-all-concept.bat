@echo off
chcp 65001 >nul
title Мониторинг - Все кластеры (Новый концепт)
echo Все кластеры - Новый концепт
echo Время: %date% %time%
call npm run cli:all-concept
pause
