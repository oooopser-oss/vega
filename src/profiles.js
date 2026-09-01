/**
 * Профили мониторинга для разных комбинаций кластер + тема обращения
 */

export const profiles = {
  // Кластер 46 - Технологическое оборудование
  'c46-tech': {
    name: 'Кластер 46 - Технологическое оборудование',
    filters: {
      clusters: ['Кластер Екатеринбург 46'],
      theme: ['tech_equipment'],
      status: 'all',
    },
  },

  // Кластер 46 - Новый концепт
  'c46-concept': {
    name: 'Кластер 46 - Новый концепт',
    filters: {
      clusters: ['Кластер Екатеринбург 46'],
      theme: ['new_concept'],
      status: 'all',
    },
  },

  // Кластер 49 - Технологическое оборудование
  'c49-tech': {
    name: 'Кластер 49 - Технологическое оборудование',
    filters: {
      clusters: ['Кластер Екатеринбург 49'],
      theme: ['tech_equipment'],
      status: 'all',
    },
  },

  // Кластер 49 - Новый концепт
  'c49-concept': {
    name: 'Кластер 49 - Новый концепт',
    filters: {
      clusters: ['Кластер Екатеринбург 49'],
      theme: ['new_concept'],
      status: 'all',
    },
  },

  // Кластер 51 - Технологическое оборудование
  'c51-tech': {
    name: 'Кластер 51 - Технологическое оборудование',
    filters: {
      clusters: ['Кластер Екатеринбург 51'],
      theme: ['tech_equipment'],
      status: 'all',
    },
  },

  // Кластер 51 - Новый концепт
  'c51-concept': {
    name: 'Кластер 51 - Новый концепт',
    filters: {
      clusters: ['Кластер Екатеринбург 51'],
      theme: ['new_concept'],
      status: 'all',
    },
  },

  // Все кластеры - Технологическое оборудование
  'all-tech': {
    name: 'Все кластеры - Технологическое оборудование',
    filters: {
      clusters: ['Кластер Екатеринбург 46', 'Кластер Екатеринбург 49', 'Кластер Екатеринбург 51'],
      theme: ['tech_equipment'],
      status: 'all',
    },
  },

  // Все кластеры - Новый концепт
  'all-concept': {
    name: 'Все кластеры - Новый концепт',
    filters: {
      clusters: ['Кластер Екатеринбург 46', 'Кластер Екатеринбург 49', 'Кластер Екатеринбург 51'],
      theme: ['new_concept'],
      status: 'all',
    },
  },

  // Все кластеры - Все темы
  'all': {
    name: 'Все кластеры - Все темы',
    filters: {
      clusters: ['Кластер Екатеринбург 46', 'Кластер Екатеринбург 49', 'Кластер Екатеринбург 51'],
      theme: ['tech_equipment', 'new_concept'],
      status: 'all',
    },
  },
};

export function getProfile(profileId) {
  return profiles[profileId] || null;
}

export function listProfiles() {
  return Object.entries(profiles).map(([id, config]) => ({
    id,
    name: config.name,
  }));
}

export default profiles;
