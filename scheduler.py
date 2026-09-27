import logging
from datetime import datetime
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger
import pytz
from config import Config
from instagram_bot import InstagramBot
from content_manager import ContentManager

logger = logging.getLogger(__name__)


class BotScheduler:
    def __init__(self):
        self.scheduler = BackgroundScheduler(timezone=pytz.timezone(Config.SCHEDULER_TIMEZONE))
        self.bot = InstagramBot()
        self.content_manager = ContentManager()
        self.is_running = False

    def start(self) -> bool:
        if self.is_running:
            logger.warning("Scheduler already running")
            return False

        if not self.bot.login():
            logger.error("Failed to login to Instagram")
            return False

        self.scheduler.start()
        self.is_running = True
        logger.info("Bot scheduler started")

        self._schedule_tasks()
        return True

    def stop(self):
        if self.is_running:
            self.scheduler.shutdown()
            self.bot.logout()
            self.is_running = False
            logger.info("Bot scheduler stopped")

    def _schedule_tasks(self):
        self.scheduler.add_job(
            self._daily_reset_stats,
            trigger=CronTrigger(hour=0, minute=0),
            id='daily_reset_stats',
            replace_existing=True
        )
        logger.info("Scheduled: Daily stats reset at 00:00")

        self.scheduler.add_job(
            self._auto_like_task,
            trigger=CronTrigger(hour='*/2'),
            id='auto_like',
            replace_existing=True
        )
        logger.info("Scheduled: Auto-like every 2 hours")

        self.scheduler.add_job(
            self._auto_follow_task,
            trigger=CronTrigger(hour='*/3'),
            id='auto_follow',
            replace_existing=True
        )
        logger.info("Scheduled: Auto-follow every 3 hours")

        if Config.AUTO_DM:
            self.scheduler.add_job(
                self._auto_dm_task,
                trigger=CronTrigger(hour='*/4'),
                id='auto_dm',
                replace_existing=True
            )
            logger.info("Scheduled: Auto-DM every 4 hours")

        self._schedule_post_times()

    def _schedule_post_times(self):
        post_times = [t.strip() for t in Config.POST_SCHEDULE.split(',')]
        for time_str in post_times:
            if ':' in time_str:
                hour, minute = map(int, time_str.split(':'))
                job_id = f'post_{hour}_{minute}'
                self.scheduler.add_job(
                    self._auto_post_task,
                    trigger=CronTrigger(hour=hour, minute=minute),
                    id=job_id,
                    replace_existing=True
                )
                logger.info(f"Scheduled: Auto-post at {hour}:{minute:02d}")

    def _daily_reset_stats(self):
        logger.info("Resetting daily statistics")
        self.bot.reset_daily_stats()

    def _auto_like_task(self):
        if not Config.AUTO_LIKE:
            return
        logger.info("Running auto-like task")
        liked = self.bot.like_posts_by_hashtags()
        logger.info(f"Auto-like completed: {liked} posts liked")

    def _auto_follow_task(self):
        if not Config.AUTO_FOLLOW:
            return
        logger.info("Running auto-follow task")
        accounts = [acc.strip() for acc in Config.TARGET_ACCOUNTS if acc.strip()]
        for account in accounts[:3]:
            followed = self.bot.follow_user_followers(account, amount=10)
            logger.info(f"Auto-follow completed for {account}: {followed} users followed")

    def _auto_post_task(self):
        logger.info("Running auto-post task")
        post = self.content_manager.get_next_post()
        if post:
            success = self.bot.upload_post(post['image'], post['caption'])
            if success:
                self.content_manager.mark_posted(post['id'])
                logger.info(f"Auto-post completed: {post['caption'][:50]}...")
            else:
                logger.error(f"Failed to post: {post['caption'][:50]}...")
        else:
            logger.warning("No posts available for scheduling")

    def _auto_dm_task(self):
        if not Config.AUTO_DM:
            return
        logger.info("Running auto-DM task")
        # DM functionality can be implemented based on requirements

    def get_status(self) -> dict:
        return {
            'is_running': self.is_running,
            'daily_stats': self.bot.get_stats(),
            'account_info': self.bot.get_account_info(),
            'scheduled_jobs': len(self.scheduler.get_jobs())
        }
