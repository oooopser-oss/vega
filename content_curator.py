import logging
import json
from typing import List, Dict, Optional
from datetime import datetime
from instagrapi import Client
from config import Config

logger = logging.getLogger(__name__)


class ContentCurator:
    def __init__(self, client: Client):
        self.client = client
        self.discovered_channels = []
        self.curated_content = []

    def discover_similar_channels(self, seed_accounts: Optional[List[str]] = None) -> List[Dict]:
        if not seed_accounts:
            seed_accounts = [acc.strip() for acc in Config.TARGET_ACCOUNTS if acc.strip()]

        similar_channels = []

        for account in seed_accounts[:5]:
            try:
                user = self.client.user_info_by_username(account)

                followers = self.client.user_followers(user.pk, amount=30)

                for follower in followers[:10]:
                    if follower.is_private:
                        continue

                    channel_info = {
                        'username': follower.username,
                        'user_id': follower.pk,
                        'followers': follower.follower_count,
                        'following': follower.following_count,
                        'posts': follower.media_count,
                        'biography': follower.biography,
                        'is_verified': follower.is_verified,
                        'discovered_at': datetime.now().isoformat()
                    }

                    if channel_info not in similar_channels:
                        similar_channels.append(channel_info)
                        logger.info(f"Discovered channel: @{follower.username}")

            except Exception as e:
                logger.warning(f"Error discovering channels from @{account}: {str(e)}")

        self.discovered_channels = similar_channels
        return similar_channels

    def evaluate_content_relevance(self, caption: str, hashtags: List[str]) -> float:
        score = 0.0
        caption_lower = caption.lower()

        for hashtag in hashtags:
            if hashtag.lower() in caption_lower:
                score += 0.3

        if any(word in caption_lower for word in ['новое', 'новый', 'fresh', 'new']):
            score += 0.1

        if any(word in caption_lower for word in ['топ', 'лучший', 'best', 'amazing']):
            score += 0.1

        engagement_indicators = ['❤', '💯', '🔥', '✨', '👍']
        if any(ind in caption for ind in engagement_indicators):
            score += 0.1

        return min(score, 1.0)

    def fetch_channel_content(self, username: str, amount: int = 10) -> List[Dict]:
        try:
            user = self.client.user_info_by_username(username)
            medias = self.client.user_medias(user.pk, amount=amount)

            content = []
            for media in medias:
                post_data = {
                    'media_id': media.id,
                    'caption': media.caption or '',
                    'likes': media.like_count,
                    'comments': media.comment_count,
                    'posted_at': media.taken_at.isoformat() if media.taken_at else None,
                    'hashtags': self._extract_hashtags(media.caption or ''),
                    'image_url': media.thumbnail_url,
                    'source_username': username,
                    'engagement_rate': (media.like_count + media.comment_count) / max(1, media.like_count)
                }

                post_data['relevance_score'] = self.evaluate_content_relevance(
                    post_data['caption'],
                    post_data['hashtags']
                )

                content.append(post_data)

            logger.info(f"Fetched {len(content)} posts from @{username}")
            return content

        except Exception as e:
            logger.error(f"Error fetching content from @{username}: {str(e)}")
            return []

    def curate_best_content(self, channels: List[str], min_relevance: float = 0.5) -> List[Dict]:
        curated = []

        for channel in channels:
            posts = self.fetch_channel_content(channel, amount=15)

            for post in posts:
                if post['relevance_score'] >= min_relevance:
                    curated.append(post)

        curated.sort(key=lambda x: (x['relevance_score'], x['engagement_rate']), reverse=True)

        self.curated_content = curated[:20]
        logger.info(f"Curated {len(self.curated_content)} relevant posts")
        return self.curated_content

    def _extract_hashtags(self, text: str) -> List[str]:
        import re
        hashtags = re.findall(r'#\w+', text)
        return list(set(hashtags))

    def save_curated_content(self, filepath: str = 'curated_posts.json'):
        try:
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(self.curated_content, f, indent=2, ensure_ascii=False)
            logger.info(f"Curated content saved to {filepath}")
        except Exception as e:
            logger.error(f"Error saving curated content: {str(e)}")
