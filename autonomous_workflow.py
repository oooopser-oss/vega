import logging
import json
from typing import List, Dict, Optional
from datetime import datetime, timedelta
from pathlib import Path
from instagram_bot import InstagramBot
from content_curator import ContentCurator
from content_rewriter import ContentRewriter
from image_matcher import ImageMatcher
from content_manager import ContentManager
from config import Config

logger = logging.getLogger(__name__)


class AutonomousContentWorkflow:
    def __init__(self):
        self.bot = InstagramBot()
        self.curator = None
        self.rewriter = ContentRewriter()
        self.image_matcher = ImageMatcher()
        self.content_manager = ContentManager()
        self.workflow_state = {
            'stage': 'idle',
            'discovered_channels': 0,
            'curated_posts': 0,
            'processed_posts': 0,
            'scheduled_posts': 0,
            'last_run': None
        }

    def login(self) -> bool:
        if self.bot.login():
            self.curator = ContentCurator(self.bot.client)
            return True
        return False

    def discover_and_curate(self, min_relevance: float = 0.5) -> Dict:
        logger.info("Starting discovery and curation workflow")
        self.workflow_state['stage'] = 'discovering'

        channels = [acc.strip() for acc in Config.TARGET_ACCOUNTS if acc.strip()]
        if not channels:
            logger.warning("No target accounts configured")
            return self.workflow_state

        similar_channels = self.curator.discover_similar_channels(channels)
        self.workflow_state['discovered_channels'] = len(similar_channels)
        logger.info(f"Discovered {len(similar_channels)} similar channels")

        if similar_channels:
            usernames = [ch['username'] for ch in similar_channels[:10]]
            curated = self.curator.curate_best_content(usernames, min_relevance)
            self.workflow_state['curated_posts'] = len(curated)
            logger.info(f"Curated {len(curated)} relevant posts")

            self.curator.save_curated_content()

            return self._process_curated_content(curated)

        return self.workflow_state

    def _process_curated_content(self, curated_posts: List[Dict]) -> Dict:
        logger.info(f"Processing {len(curated_posts)} curated posts")
        self.workflow_state['stage'] = 'processing'

        processed_posts = []

        for post in curated_posts[:10]:
            try:
                rewritten_caption = self.rewriter.rewrite_caption(
                    post['caption'],
                    style='engaging'
                )

                optimized_caption = self.rewriter.optimize_for_algorithm(rewritten_caption)

                matching_images = self.image_matcher.find_matching_images(
                    optimized_caption,
                    limit=3
                )

                processed_post = {
                    'source': post['source_username'],
                    'original_caption': post['caption'],
                    'rewritten_caption': rewritten_caption,
                    'optimized_caption': optimized_caption,
                    'matching_images': matching_images,
                    'relevance_score': post['relevance_score'],
                    'engagement_rate': post['engagement_rate'],
                    'processed_at': datetime.now().isoformat()
                }

                processed_posts.append(processed_post)
                logger.info(f"Processed post from @{post['source_username']}")

            except Exception as e:
                logger.error(f"Error processing post: {str(e)}")

        self.workflow_state['processed_posts'] = len(processed_posts)

        self._save_processed_posts(processed_posts)

        return self.workflow_state

    def schedule_processed_content(self, posts: List[Dict]) -> int:
        logger.info(f"Scheduling {len(posts)} processed posts")
        self.workflow_state['stage'] = 'scheduling'

        scheduled_count = 0
        post_times = [t.strip() for t in Config.POST_SCHEDULE.split(',')]

        for i, post in enumerate(posts):
            try:
                schedule_time = post_times[i % len(post_times)] if post_times else None

                scheduled_post = self.content_manager.add_post(
                    image_path=post['matching_images'][0]['path'] if post['matching_images'] else 'placeholder.jpg',
                    caption=post['optimized_caption'],
                    scheduled_time=schedule_time
                )

                scheduled_count += 1
                logger.info(f"Scheduled post #{scheduled_post['id']} for {schedule_time}")

            except Exception as e:
                logger.error(f"Error scheduling post: {str(e)}")

        self.workflow_state['scheduled_posts'] = scheduled_count
        self.workflow_state['last_run'] = datetime.now().isoformat()

        return scheduled_count

    def _save_processed_posts(self, posts: List[Dict]):
        try:
            filepath = Config.CONTENT_DIR / 'processed_posts.json'
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(posts, f, indent=2, ensure_ascii=False)
            logger.info(f"Processed posts saved to {filepath}")
        except Exception as e:
            logger.error(f"Error saving processed posts: {str(e)}")

    def load_image_library(self, directory: Optional[str] = None) -> int:
        if not directory:
            directory = str(Config.CONTENT_DIR / 'images')

        loaded = self.image_matcher.load_image_library(directory)
        logger.info(f"Loaded {len(loaded)} images from library")
        return len(loaded)

    def full_workflow(self, min_relevance: float = 0.5, auto_schedule: bool = True) -> Dict:
        logger.info("Starting full autonomous workflow")

        if not self.login():
            logger.error("Failed to login")
            return {'error': 'Login failed'}

        self.load_image_library()

        discovery_result = self.discover_and_curate(min_relevance)

        if discovery_result.get('curated_posts', 0) == 0:
            logger.warning("No curated posts found")
            return discovery_result

        if auto_schedule:
            processed_posts = self._load_processed_posts()
            if processed_posts:
                scheduled = self.schedule_processed_content(processed_posts)
                logger.info(f"Auto-scheduled {scheduled} posts")

        self.bot.logout()

        return self.workflow_state

    def _load_processed_posts(self) -> List[Dict]:
        try:
            filepath = Config.CONTENT_DIR / 'processed_posts.json'
            if filepath.exists():
                with open(filepath, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception as e:
            logger.error(f"Error loading processed posts: {str(e)}")

        return []

    def get_workflow_report(self) -> Dict:
        return {
            'workflow_state': self.workflow_state,
            'content_stats': self.content_manager.get_stats(),
            'bot_stats': self.bot.get_stats() if self.bot.is_logged_in else None,
            'image_library_size': len(self.image_matcher.image_library),
            'timestamp': datetime.now().isoformat()
        }

    def cleanup_old_posts(self, days: int = 30) -> int:
        logger.info(f"Cleaning up posts older than {days} days")

        cutoff_date = datetime.now() - timedelta(days=days)
        initial_count = len(self.content_manager.get_posted_posts())

        self.content_manager.posts = [
            p for p in self.content_manager.posts
            if not p['posted_at'] or datetime.fromisoformat(p['posted_at']) > cutoff_date
        ]

        self.content_manager._save_posts()
        final_count = len(self.content_manager.get_posted_posts())
        removed = initial_count - final_count

        logger.info(f"Removed {removed} old posts")
        return removed
