import './common.js';
import './resolved';

const text = t('forms.button.submit');
const message = t('forms.messages', { count: 2 });
const values = t(['forms.key1', 'forms.key2']);

// i18n-tasks-use t('item.1')
/* i18n-tasks-use t('item.2') */
/**
 * i18n-tasks-use t('item.3')
 */
Array.from({ length: 3 }, (_, i) => t(`item.${i + 1}`));
// Emulate Babel template literal transpilation
// See: https://babeljs.io/repl#?browsers=ie%2011&code_lz=C4CgBglsCmC2B0ASA3hABAajQRgL5gEog
Array.from({ length: 3 }, (_, i) => t('item.'.concat(i + 1)));
