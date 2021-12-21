import './common.js';

const text = t('forms.button.submit');

// i18n-tasks-use t('item.1')
/* i18n-tasks-use t('item.2') */
/**
 * i18n-tasks-use t('item.3')
 */
Array.from({ length: 3 }, (_, i) => t(`item.${i + 1}`));
