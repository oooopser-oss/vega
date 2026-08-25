import logging
import re
from typing import List, Dict, Optional, Tuple
from pathlib import Path
import json

logger = logging.getLogger(__name__)


class ImageMatcher:
    def __init__(self):
        self.image_library = []
        self.content_keywords_map = {
            'природа': ['пейзаж', 'лес', 'горы', 'вода', 'небо', 'закат', 'восход'],
            'люди': ['портрет', 'лица', 'улица', 'фото', 'улыбка'],
            'еда': ['еда', 'напиток', 'кофе', 'десерт', 'блюдо', 'рецепт'],
            'архитектура': ['здание', 'дом', 'улица', 'город', 'сооружение'],
            'мода': ['стиль', 'одежда', 'мода', 'наряд', 'платье', 'обувь'],
            'путешествия': ['путешествие', 'поездка', 'страна', 'город', 'туризм'],
            'спорт': ['спорт', 'фитнес', 'тренировка', 'бег', 'йога'],
        }

    def load_image_library(self, directory: str) -> List[Dict]:
        try:
            path = Path(directory)
            if not path.exists():
                logger.warning(f"Image directory not found: {directory}")
                return []

            self.image_library = []

            for image_file in path.glob('*.jpg') | path.glob('*.png') | path.glob('*.jpeg'):
                image_info = {
                    'filename': image_file.name,
                    'path': str(image_file),
                    'size': image_file.stat().st_size,
                    'tags': self._extract_tags_from_filename(image_file.name),
                }
                self.image_library.append(image_info)

            logger.info(f"Loaded {len(self.image_library)} images from library")
            return self.image_library

        except Exception as e:
            logger.error(f"Error loading image library: {str(e)}")
            return []

    def find_matching_images(self, text: str, limit: int = 5) -> List[Dict]:
        keywords = self._extract_keywords(text)
        logger.info(f"Extracted keywords: {keywords}")

        if not self.image_library:
            logger.warning("Image library is empty")
            return []

        scored_images = []

        for image in self.image_library:
            score = self._calculate_match_score(keywords, image['tags'])
            scored_images.append({
                **image,
                'match_score': score
            })

        scored_images.sort(key=lambda x: x['match_score'], reverse=True)

        return scored_images[:limit]

    def _extract_keywords(self, text: str) -> List[str]:
        text_lower = text.lower()
        keywords = []

        for category, words in self.content_keywords_map.items():
            for word in words:
                if word in text_lower:
                    keywords.append(word)
                    if category not in keywords:
                        keywords.append(category)

        keywords = list(set(keywords))
        return keywords

    def _extract_tags_from_filename(self, filename: str) -> List[str]:
        name_without_ext = Path(filename).stem

        name_lower = name_without_ext.lower()

        tags = []
        for category, words in self.content_keywords_map.items():
            for word in words:
                if word in name_lower:
                    tags.append(word)
            if category in name_lower:
                tags.append(category)

        return list(set(tags))

    def _calculate_match_score(self, text_keywords: List[str], image_tags: List[str]) -> float:
        if not image_tags:
            return 0.0

        matches = len(set(text_keywords) & set(image_tags))
        score = matches / len(set(image_tags).union(set(text_keywords)))

        return score

    def suggest_content_for_image(self, image_path: str) -> Dict:
        image_name = Path(image_path).stem.lower()
        tags = self._extract_tags_from_filename(image_path)

        suggestions = {
            'image_path': image_path,
            'detected_tags': tags,
            'suggested_topics': [],
            'suggested_captions': []
        }

        if 'природа' in tags or 'пейзаж' in tags:
            suggestions['suggested_topics'].append('Путешествия и природа')
            suggestions['suggested_captions'].append(
                'Красота природы поражает! Каждый закат — это уникальный шедевр. ✨'
            )

        if 'еда' in tags:
            suggestions['suggested_topics'].append('Кулинария и рецепты')
            suggestions['suggested_captions'].append(
                'Вкусная история в каждой фотографии! 🍽️ #рецепты #еда'
            )

        if 'люди' in tags or 'портрет' in tags:
            suggestions['suggested_topics'].append('Портреты и истории')
            suggestions['suggested_captions'].append(
                'Каждое лицо рассказывает историю 📸 #портрет #люди'
            )

        if 'мода' in tags or 'стиль' in tags:
            suggestions['suggested_topics'].append('Мода и стиль')
            suggestions['suggested_captions'].append(
                'Стиль - это выражение личности! ✨👗 #мода #стиль'
            )

        return suggestions

    def batch_match_images(self, captions: List[str]) -> List[Dict]:
        results = []

        for i, caption in enumerate(captions):
            matching_images = self.find_matching_images(caption, limit=3)
            results.append({
                'caption_index': i,
                'caption_text': caption[:100],
                'matching_images': matching_images
            })

        return results

    def create_image_metadata(self, image_path: str, caption: str) -> Dict:
        return {
            'image_path': image_path,
            'caption': caption,
            'tags': self._extract_keywords(caption),
            'metadata': {
                'matched_at': Path(image_path).stat().st_mtime,
                'caption_keywords': len(self._extract_keywords(caption))
            }
        }

    def save_image_mappings(self, mappings: List[Dict], output_file: str = 'image_mappings.json'):
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(mappings, f, indent=2, ensure_ascii=False)
            logger.info(f"Image mappings saved to {output_file}")
        except Exception as e:
            logger.error(f"Error saving image mappings: {str(e)}")
