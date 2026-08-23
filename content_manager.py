import json
import logging
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict
from config import Config

logger = logging.getLogger(__name__)


class ContentManager:
    def __init__(self):
        self.content_file = Config.CONTENT_DIR / 'posts.json'
        self.load_posts()

    def load_posts(self):
        if not self.content_file.exists():
            self.posts = []
            self._save_posts()
        else:
            try:
                with open(self.content_file, 'r', encoding='utf-8') as f:
                    self.posts = json.load(f)
            except Exception as e:
                logger.error(f"Failed to load posts: {str(e)}")
                self.posts = []

    def _save_posts(self):
        try:
            with open(self.content_file, 'w', encoding='utf-8') as f:
                json.dump(self.posts, f, indent=2, ensure_ascii=False)
        except Exception as e:
            logger.error(f"Failed to save posts: {str(e)}")

    def add_post(self, image_path: str, caption: str, scheduled_time: Optional[str] = None) -> Dict:
        post_id = len(self.posts) + 1
        post = {
            'id': post_id,
            'image': image_path,
            'caption': caption,
            'scheduled_time': scheduled_time,
            'posted': False,
            'posted_at': None,
            'created_at': datetime.now().isoformat()
        }
        self.posts.append(post)
        self._save_posts()
        logger.info(f"Post #{post_id} added: {caption[:50]}...")
        return post

    def get_next_post(self) -> Optional[Dict]:
        for post in self.posts:
            if not post['posted']:
                return post
        return None

    def mark_posted(self, post_id: int) -> bool:
        for post in self.posts:
            if post['id'] == post_id:
                post['posted'] = True
                post['posted_at'] = datetime.now().isoformat()
                self._save_posts()
                logger.info(f"Post #{post_id} marked as posted")
                return True
        return False

    def get_all_posts(self) -> List[Dict]:
        return self.posts.copy()

    def get_posted_posts(self) -> List[Dict]:
        return [p for p in self.posts if p['posted']]

    def get_pending_posts(self) -> List[Dict]:
        return [p for p in self.posts if not p['posted']]

    def delete_post(self, post_id: int) -> bool:
        self.posts = [p for p in self.posts if p['id'] != post_id]
        self._save_posts()
        logger.info(f"Post #{post_id} deleted")
        return True

    def get_stats(self) -> Dict:
        total = len(self.posts)
        posted = len([p for p in self.posts if p['posted']])
        pending = total - posted
        return {
            'total_posts': total,
            'posted': posted,
            'pending': pending
        }
