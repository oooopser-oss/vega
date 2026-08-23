import logging
import re
from typing import List, Dict, Optional
from datetime import datetime

logger = logging.getLogger(__name__)


class ContentRewriter:
    def __init__(self):
        self.rewritten_cache = {}

        self.synonym_map = {
            'красивый': ['прекрасный', 'чудесный', 'восхитительный', 'очаровательный'],
            'лучший': ['превосходный', 'замечательный', 'отличный', 'изумительный'],
            'новый': ['свежий', 'неожиданный', 'инновационный', 'оригинальный'],
            'хороший': ['отменный', 'качественный', 'потрясающий', 'супер'],
            'интересный': ['увлекательный', 'захватывающий', 'любопытный', 'манящий'],
        }

        self.engagement_starters = [
            'Посмотрите на это! ',
            'Вот это да! ',
            'Не пропустите: ',
            'Просто шедевр: ',
            'Обязательно смотрите: ',
            'Вам понравится: ',
            'Потрясающе: ',
        ]

        self.engagement_closers = [
            ' 👍',
            ' ✨',
            ' 🔥',
            ' 💯',
            ' ❤️',
        ]

    def rewrite_caption(self, original_caption: str, style: str = 'engaging') -> str:
        if not original_caption:
            return ''

        logger.info(f"Rewriting caption with style: {style}")

        text = original_caption.strip()

        text = self._enhance_vocabulary(text)

        text = self._improve_structure(text)

        if style == 'engaging':
            text = self._add_engagement(text)
        elif style == 'professional':
            text = self._make_professional(text)
        elif style == 'casual':
            text = self._make_casual(text)

        text = self._clean_excessive_hashtags(text)

        return text

    def _enhance_vocabulary(self, text: str) -> str:
        for original, synonyms in self.synonym_map.items():
            if original in text.lower():
                pattern = re.compile(re.escape(original), re.IGNORECASE)
                replacement = synonyms[0]
                text = pattern.sub(replacement, text, count=1)

        return text

    def _improve_structure(self, text: str) -> str:
        sentences = re.split(r'(?<=[.!?])\s+', text)

        if len(sentences) > 1:
            sentences[0] = sentences[0].capitalize()

        text = ' '.join(sentences)

        text = re.sub(r'\s+([,.])', r'\1', text)

        return text

    def _add_engagement(self, text: str) -> str:
        import random

        if not text.startswith(tuple(self.engagement_starters)):
            text = random.choice(self.engagement_starters) + text

        if not any(text.strip().endswith(closer.strip()) for closer in self.engagement_closers):
            text += random.choice(self.engagement_closers)

        return text

    def _make_professional(self, text: str) -> str:
        text = re.sub(r'[!]{2,}', '!', text)
        text = re.sub(r'\.\.\.$', '.', text)

        text = re.sub(r'\b(OMG|WOW|OMG|OMGG)\b', 'Замечательно', text, flags=re.IGNORECASE)

        return text

    def _make_casual(self, text: str) -> str:
        text = re.sub(r'Замечательно', 'Ну ты даёшь!', text)
        text = re.sub(r'Спасибо', 'Спасибочки', text)

        return text

    def _clean_excessive_hashtags(self, text: str) -> str:
        hashtags = re.findall(r'#\w+', text)

        if len(hashtags) > 25:
            non_hashtag_text = re.sub(r'#\w+\s*', '', text).strip()
            top_hashtags = hashtags[:25]
            text = non_hashtag_text + '\n\n' + ' '.join(top_hashtags)

        return text

    def batch_rewrite(self, captions: List[str], style: str = 'engaging') -> List[Dict]:
        results = []

        for i, caption in enumerate(captions):
            rewritten = self.rewrite_caption(caption, style)
            results.append({
                'original': caption,
                'rewritten': rewritten,
                'length_before': len(caption),
                'length_after': len(rewritten),
                'index': i
            })
            logger.info(f"Rewritten caption {i + 1}/{len(captions)}")

        return results

    def suggest_improvements(self, caption: str) -> List[str]:
        suggestions = []

        if len(caption) < 20:
            suggestions.append('Текст очень короткий, расширьте описание')

        if len(caption) > 2200:
            suggestions.append('Текст слишком длинный (макс 2200 символов)')

        if not re.search(r'#\w+', caption):
            suggestions.append('Добавьте релевантные хештеги')

        if caption.count('!') > 5:
            suggestions.append('Уменьшите количество восклицательных знаков')

        if not any(emoji in caption for emoji in ['❤', '💯', '🔥', '✨', '👍']):
            suggestions.append('Добавьте емодзи для лучшего взаимодействия')

        hashtags = re.findall(r'#\w+', caption)
        if len(hashtags) < 5:
            suggestions.append(f'Добавьте больше хештегов (сейчас {len(hashtags)})')

        if len(hashtags) > 30:
            suggestions.append(f'Уменьшите количество хештегов (сейчас {len(hashtags)}, макс 30)')

        return suggestions

    def optimize_for_algorithm(self, caption: str) -> str:
        text = caption.strip()

        if len(text) > 125:
            first_line = text[:125]
            rest = text[125:]
            text = first_line + '\n\n' + rest

        text = text.replace('  ', ' ')

        hashtags = re.findall(r'#\w+', text)
        non_hashtag_text = re.sub(r'#\w+\s*', '', text).strip()

        if hashtags and non_hashtag_text:
            text = non_hashtag_text + '\n\n' + ' '.join(hashtags)

        return text
