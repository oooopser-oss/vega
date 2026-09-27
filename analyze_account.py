#!/usr/bin/env python3
"""
Скрипт анализа Instagram аккаунта
Использует локальные credentaials для получения полной статистики
"""

import sys
import json
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from dotenv import load_dotenv
from instagram_bot import InstagramBot
from config import Config

def analyze_account():
    """Провести полный анализ аккаунта"""

    # Load credentials
    load_dotenv('.env')

    bot = InstagramBot()

    print("\n" + "=" * 70)
    print("📊 АНАЛИЗ INSTAGRAM АККАУНТА")
    print("=" * 70 + "\n")

    print("🔐 Подключение к Instagram...")
    if not bot.login():
        print("✗ Ошибка: не удалось подключиться")
        print("Проверьте .env файл с учётными данными")
        return

    print("✓ Успешно подключены!\n")

    try:
        # Get account info
        account = bot.get_account_info()

        print("=" * 70)
        print(f"ПРОФИЛЬ: @{account.get('username', 'unknown')}")
        print("=" * 70)

        # Basic info
        print(f"\n📱 ИНФОРМАЦИЯ:")
        print(f"   Имя: {account.get('full_name', 'N/A')}")
        print(f"   Биография: {account.get('biography', 'N/A')}")
        print(f"   Сайт: {account.get('external_url', 'Не указан')}")

        # Statistics
        print(f"\n📈 СТАТИСТИКА:")
        followers = account.get('follower_count', 0)
        following = account.get('following_count', 0)
        posts = account.get('media_count', 0)

        print(f"   Подписчики: {followers:,}")
        print(f"   Подписки: {following:,}")
        print(f"   Посты: {posts:,}")

        # Analysis
        print(f"\n📊 АНАЛИЗ:")

        if followers > 0 and following > 0:
            ratio = following / followers
            print(f"   Соотношение подписки/подписчики: {ratio:.2f}")
            if ratio < 0.5:
                print("   ✓ Отличное соотношение - подписчиков намного больше")
            elif ratio < 1:
                print("   ✓ Хорошее соотношение")
            else:
                print("   ⚠️  Следуете большему количеству аккаунтов")

        if posts > 0:
            print(f"   Среднее подписчиков на пост: {followers / posts:.0f}")
            print(f"   Постов в месяц: ~{(posts / 12):.1f}")

        # Account type
        print(f"\n🎯 ТИП АККАУНТА:")
        print(f"   Бизнес: {'✓' if account.get('is_business_account') else '✗'}")
        print(f"   Верифицирован: {'✓' if account.get('is_verified') else '✗'}")
        print(f"   Приватный: {'✓' if account.get('is_private') else '✗'}")

        # Daily stats
        stats = bot.get_stats()
        if stats:
            print(f"\n💪 АКТИВНОСТЬ СЕГОДНЯ:")
            print(f"   Лайков: {stats.get('likes_today', 0)}/{stats.get('daily_likes_limit', 100)}")
            print(f"   Подписок: {stats.get('follows_today', 0)}/{stats.get('daily_follows_limit', 50)}")

        # Recommendations
        print("\n" + "=" * 70)
        print("💡 РЕКОМЕНДАЦИИ ДЛЯ АВТОМАТИЗАЦИИ:")
        print("=" * 70)
        print("\n1. 🔍 Поиск похожих каналов:")
        print("   python main.py workflow-cmds discover --min-relevance 0.6")

        print("\n2. ✏️  Рерайт контента:")
        print("   python main.py workflow-cmds rewrite --text 'ваш текст' --style engaging")

        print("\n3. 🖼️  Подбор изображений:")
        print("   python main.py workflow-cmds match-images --text 'описание'")

        print("\n4. 🚀 Полный цикл:")
        print("   mkdir -p content/images  # Создайте папку для фото")
        print("   python main.py workflow-cmds full-workflow")

        print("\n5. 📅 Запуск бота в фоне:")
        print("   python main.py start")

        # Save analysis
        analysis = {
            'timestamp': datetime.now().isoformat(),
            'account': account,
            'stats': stats
        }

        with open('account_analysis.json', 'w', encoding='utf-8') as f:
            json.dump(analysis, f, indent=2, ensure_ascii=False, default=str)

        print("\n✓ Анализ сохранён в account_analysis.json")

    except Exception as e:
        print(f"\n✗ Ошибка при анализе: {str(e)}")

    finally:
        bot.logout()
        print("\n✓ Сессия закрыта")

if __name__ == '__main__':
    analyze_account()
