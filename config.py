import os
from dotenv import load_dotenv
from pathlib import Path

load_dotenv()

class Config:
    # Instagram credentials
    INSTAGRAM_USERNAME = os.getenv('INSTAGRAM_USERNAME')
    INSTAGRAM_PASSWORD = os.getenv('INSTAGRAM_PASSWORD')

    # Bot settings
    PROXY = os.getenv('PROXY')
    HEADLESS_BROWSER = os.getenv('HEADLESS_BROWSER', 'True') == 'True'

    # Scheduler settings
    SCHEDULER_TIMEZONE = os.getenv('SCHEDULER_TIMEZONE', 'UTC')

    # Database
    DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///instagram_bot.db')

    # Engagement settings
    AUTO_LIKE = os.getenv('AUTO_LIKE', 'True') == 'True'
    AUTO_FOLLOW = os.getenv('AUTO_FOLLOW', 'True') == 'True'
    AUTO_COMMENT = os.getenv('AUTO_COMMENT', 'False') == 'True'
    AUTO_DM = os.getenv('AUTO_DM', 'False') == 'True'

    # Daily limits (to avoid detection)
    DAILY_LIKES_LIMIT = int(os.getenv('DAILY_LIKES_LIMIT', '100'))
    DAILY_FOLLOWS_LIMIT = int(os.getenv('DAILY_FOLLOWS_LIMIT', '50'))
    DAILY_COMMENTS_LIMIT = int(os.getenv('DAILY_COMMENTS_LIMIT', '30'))

    # Hashtags for engagement
    TARGET_HASHTAGS = os.getenv('TARGET_HASHTAGS', '').split(',')
    TARGET_ACCOUNTS = os.getenv('TARGET_ACCOUNTS', '').split(',')

    # Content scheduling
    POST_SCHEDULE = os.getenv('POST_SCHEDULE', '08:00,14:00,20:00')  # Times to post

    # Paths
    BASE_DIR = Path(__file__).parent
    CONTENT_DIR = BASE_DIR / 'content'
    LOGS_DIR = BASE_DIR / 'logs'

    @classmethod
    def init_directories(cls):
        cls.CONTENT_DIR.mkdir(exist_ok=True)
        cls.LOGS_DIR.mkdir(exist_ok=True)
