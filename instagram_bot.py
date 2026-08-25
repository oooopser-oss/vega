import logging
import random
import time
from pathlib import Path
from datetime import datetime
from typing import List, Optional
from instagrapi import Client
from instagrapi.exceptions import LoginRequired
from config import Config

# Ensure directories exist
Config.LOGS_DIR.mkdir(parents=True, exist_ok=True)
Config.CONTENT_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(Config.LOGS_DIR / f'bot_{datetime.now().strftime("%Y%m%d")}.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class InstagramBot:
    def __init__(self):
        self.client = Client()
        self.is_logged_in = False
        self.daily_stats = {
            'likes': 0,
            'follows': 0,
            'comments': 0,
            'posts': 0
        }

    def login(self) -> bool:
        try:
            # Try to load saved session first
            try:
                self.client.load_settings(Config.INSTAGRAM_USERNAME)
                logger.info(f"Loaded saved session for {Config.INSTAGRAM_USERNAME}")
                self.is_logged_in = True
                return True
            except Exception:
                pass

            # Set up challenge handler for Instagram verification
            self.client.challenge_code_handler = self._handle_challenge

            # Login with credentials
            self.client.login(Config.INSTAGRAM_USERNAME, Config.INSTAGRAM_PASSWORD)
            self.is_logged_in = True
            logger.info(f"Successfully logged in as {Config.INSTAGRAM_USERNAME}")
            return True
        except LoginRequired:
            logger.error("Login failed: Invalid credentials")
            return False
        except Exception as e:
            logger.error(f"Login error: {str(e)}")
            return False

    def _handle_challenge(self, username: str, choice: str) -> str:
        """Handle Instagram challenge (2FA/verification)"""
        logger.info(f"Instagram verification required for {username}")
        print(f"\n⚠️  Требуется верификация Instagram для {username}")
        print(f"   Выберите способ верификации: {choice}")
        code = input("   Введите код верификации: ").strip()
        return code

    def logout(self):
        if self.is_logged_in:
            try:
                self.client.save_settings(Config.INSTAGRAM_USERNAME)
                logger.info("Session saved for next login")
            except Exception as e:
                logger.debug(f"Could not save session: {str(e)}")

            self.client.logout()
            self.is_logged_in = False
            logger.info("Logged out successfully")

    def like_posts_by_hashtags(self, hashtags: Optional[List[str]] = None) -> int:
        if not self.is_logged_in:
            return 0

        hashtags = hashtags or [tag.strip() for tag in Config.TARGET_HASHTAGS if tag.strip()]
        liked_count = 0

        for hashtag in hashtags:
            if self.daily_stats['likes'] >= Config.DAILY_LIKES_LIMIT:
                break

            try:
                medias = self.client.hashtag_medias_recent(hashtag, amount=10)
                for media in medias:
                    if self.daily_stats['likes'] >= Config.DAILY_LIKES_LIMIT:
                        break

                    try:
                        self.client.media_like(media.id)
                        self.daily_stats['likes'] += 1
                        liked_count += 1
                        logger.info(f"Liked post #{media.id} from #{hashtag}")
                        time.sleep(random.uniform(2, 8))
                    except Exception as e:
                        logger.warning(f"Failed to like post: {str(e)}")
            except Exception as e:
                logger.warning(f"Error getting hashtag medias for #{hashtag}: {str(e)}")

        return liked_count

    def follow_accounts_by_hashtags(self, hashtags: Optional[List[str]] = None) -> int:
        if not self.is_logged_in:
            return 0

        hashtags = hashtags or [tag.strip() for tag in Config.TARGET_HASHTAGS if tag.strip()]
        followed_count = 0

        for hashtag in hashtags:
            if self.daily_stats['follows'] >= Config.DAILY_FOLLOWS_LIMIT:
                break

            try:
                medias = self.client.hashtag_medias_recent(hashtag, amount=10)
                for media in medias:
                    if self.daily_stats['follows'] >= Config.DAILY_FOLLOWS_LIMIT:
                        break

                    try:
                        self.client.user_follow(media.user_id)
                        self.daily_stats['follows'] += 1
                        followed_count += 1
                        logger.info(f"Followed user {media.user_id} from #{hashtag}")
                        time.sleep(random.uniform(3, 10))
                    except Exception as e:
                        logger.warning(f"Failed to follow user: {str(e)}")
            except Exception as e:
                logger.warning(f"Error getting hashtag medias for #{hashtag}: {str(e)}")

        return followed_count

    def follow_user_followers(self, username: str, amount: int = 20) -> int:
        if not self.is_logged_in:
            return 0

        try:
            user = self.client.user_info_by_username(username)
            followers = self.client.user_followers(user.pk, amount=amount)
            followed_count = 0

            for follower in followers:
                if self.daily_stats['follows'] >= Config.DAILY_FOLLOWS_LIMIT:
                    break

                try:
                    self.client.user_follow(follower.pk)
                    self.daily_stats['follows'] += 1
                    followed_count += 1
                    logger.info(f"Followed {follower.username}")
                    time.sleep(random.uniform(3, 10))
                except Exception as e:
                    logger.warning(f"Failed to follow {follower.username}: {str(e)}")

            return followed_count
        except Exception as e:
            logger.error(f"Error following {username}'s followers: {str(e)}")
            return 0

    def upload_post(self, image_path: str, caption: str = "", location: Optional[str] = None) -> bool:
        if not self.is_logged_in:
            return False

        try:
            self.client.photo_upload(
                Path(image_path),
                caption=caption,
                location=location
            )
            self.daily_stats['posts'] += 1
            logger.info(f"Successfully uploaded post: {image_path}")
            return True
        except Exception as e:
            logger.error(f"Failed to upload post: {str(e)}")
            return False

    def get_account_info(self):
        if not self.is_logged_in:
            return None

        try:
            user_info = self.client.account_info()
            return {
                'username': user_info.username,
                'followers': user_info.follower_count,
                'following': user_info.following_count,
                'posts': user_info.media_count,
                'biography': user_info.biography
            }
        except Exception as e:
            logger.error(f"Failed to get account info: {str(e)}")
            return None

    def reset_daily_stats(self):
        self.daily_stats = {
            'likes': 0,
            'follows': 0,
            'comments': 0,
            'posts': 0
        }
        logger.info("Daily stats reset")

    def get_stats(self) -> dict:
        return self.daily_stats.copy()
