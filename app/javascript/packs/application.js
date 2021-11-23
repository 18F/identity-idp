import { I18n } from '@18f/identity-i18n';

/**
 * @typedef {Window & {
 *   _locale_data?: Record<string, string>
 * }} WindowWithLocaleData
 */

const { _locale_data: strings } = /** @type {WindowWithLocaleData} */ (window);

window.LoginGov = window.LoginGov || {};
window.LoginGov.I18n = new I18n({ strings });

require('../app/components/index');
require('../app/utils/index');
require('../app/pw-toggle');
require('../app/print-personal-key');
require('../app/i18n-dropdown');
