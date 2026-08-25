import os
import re
from pathlib import Path
from datetime import datetime, timedelta
import hashlib


def validate_instagram_username(username: str) -> bool:
    pattern = r'^[a-zA-Z0-9._]{1,30}$'
    return bool(re.match(pattern, username))


def validate_hashtag(hashtag: str) -> bool:
    if not hashtag.startswith('#'):
        return False
    pattern = r'^#[a-zA-Z0-9_]{1,}$'
    return bool(re.match(pattern, hashtag))


def clean_hashtags(hashtags_str: str) -> list:
    hashtags = [tag.strip() for tag in hashtags_str.split(',')]
    return [tag for tag in hashtags if tag]


def get_file_hash(filepath: str) -> str:
    hasher = hashlib.md5()
    with open(filepath, 'rb') as f:
        hasher.update(f.read())
    return hasher.hexdigest()


def get_image_info(filepath: str) -> dict:
    try:
        from PIL import Image
        img = Image.open(filepath)
        return {
            'size': os.path.getsize(filepath),
            'dimensions': img.size,
            'format': img.format
        }
    except Exception as e:
        return {'error': str(e)}


def format_timestamp(dt: datetime) -> str:
    return dt.strftime('%Y-%m-%d %H:%M:%S')


def time_diff_str(dt: datetime) -> str:
    diff = datetime.now() - dt
    if diff.days > 0:
        return f"{diff.days} дней назад"
    elif diff.seconds > 3600:
        return f"{diff.seconds // 3600} часов назад"
    elif diff.seconds > 60:
        return f"{diff.seconds // 60} минут назад"
    else:
        return "Только что"


def is_optimal_posting_time() -> bool:
    hour = datetime.now().hour
    return 8 <= hour <= 22


def get_next_optimal_time() -> datetime:
    now = datetime.now()
    if now.hour >= 22:
        next_time = (now + timedelta(days=1)).replace(hour=8, minute=0, second=0)
    elif now.hour < 8:
        next_time = now.replace(hour=8, minute=0, second=0)
    else:
        next_time = now
    return next_time
