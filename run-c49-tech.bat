@echo off
chcp 65001 >nul
title Мониторинг - Кластер 49 (Технологическое)
echo Кластер 49 - Технологическое оборудование
echo Время: %date% %time%
call npm run cli:c49-tech
pause
