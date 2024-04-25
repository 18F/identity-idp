const { promises: fs } = require('fs');
const { format } = require('util');
const path = require('path');
const YAML = require('yaml');
const ExtractKeysWebpackPlugin = require('./extract-keys-webpack-plugin.js');

/**
 * @typedef {(key: string, locale: string) => string|undefined|void} MissingStringCallback
 */

/**
 * @typedef RailsI18nWebpackPluginOptions
 *
 * @prop {string} template String to format using locale data object, generated using util.format.
 * @prop {string} configPath Root path for locale configuration data.
 * @prop {string} defaultLocale Default locale to use if string data is missing for desired locale.
 * @prop {MissingStringCallback} onMissingString Callback to call when a key is missing, optionally
 * returning a string to use in its place.
 */

/**
 * Returns truthy values from the given array.
 *
 * @template V
 *
 * @param {Array<V|undefined>} values
 *
 * @returns {V[]}
 */
const compact = (values) => /** @type {V[]} */ (values.filter(Boolean));

/**
 * @extends {ExtractKeysWebpackPlugin<RailsI18nWebpackPluginOptions>}
 */
class RailsI18nWebpackPlugin extends ExtractKeysWebpackPlugin {
  /** @type {RailsI18nWebpackPluginOptions} */
  static DEFAULT_OPTIONS = {
    template: '_locale_data=Object.assign(%j,this._locale_data)',
    configPath: path.resolve(process.cwd(), 'config/locales'),
    defaultLocale: 'en',
    onMissingString: () => {},
  };

  /**
   * Cached locale data.
   *
   * @type {{
   *   [locale: string]: Promise<{ [key: string]: string }>
   * }}
   */
  localeData = Object.create(null);

  /**
   * Given a translation domain and locale, returns the file path corresponding to locale data.
   *
   * @param {string} locale
   *
   * @return {string}
   */
  getLocaleFilePath(locale) {
    return path.resolve(this.options.configPath, `${locale}.yml`);
  }

  /**
   * Returns a promise resolving to parsed YAML data for the given domain and locale.
   *
   * @param {string} locale
   *
   * @return {Promise<undefined|Record<string, string>>}
   */
  getLocaleData(locale) {
    if (!(locale in this.localeData)) {
      const localePath = this.getLocaleFilePath(locale);

      this.localeData[locale] = fs
        .readFile(localePath, 'utf-8')
        .then(YAML.parse)
        .catch(() => {});
    }

    return this.localeData[locale];
  }

  /**
   * Returns a promise resolving to the translated value for a locale key, if it exists.
   *
   * @param {string} key
   * @param {string} locale
   * @param {MissingStringCallback} onMissingString
   *
   * @return {Promise<string>}
   */
  async resolveTranslation(key, locale, onMissingString = this.options.onMissingString) {
    const localeData = await this.getLocaleData(locale);

    let translation = localeData?.[key];
    if (translation === undefined) {
      translation = onMissingString(key, locale);
    }

    if (translation === undefined && locale !== this.options.defaultLocale) {
      translation = await this.resolveTranslation(key, this.options.defaultLocale, () => {});
    }

    return translation || '';
  }

  /**
   * Returns a promise resolving to unique locales for the given domain.
   *
   * @return {Promise<string[]>}
   */
  async getLocales() {
    const localeFiles = await fs.readdir(this.options.configPath);

    return localeFiles
      .filter((file) => file.endsWith('.yml'))
      .map((file) => path.basename(file, '.yml'));
  }

  /**
   *
   * @param {string[]} keys
   * @param {string} locale
   *
   * @return {Promise<Record<string,string>|undefined>}
   */
  async getTranslationData(keys, locale) {
    /**
     * @param {string} key
     *
     * @return {Promise<[key: string, string: string]>}
     */
    const getKeyTranslationPairs = async (key) => [key, await this.resolveTranslation(key, locale)];

    const translations = await Promise.all(keys.map(getKeyTranslationPairs));
    if (translations.length) {
      return Object.fromEntries(translations);
    }
  }

  async getAdditionalAssets(keys) {
    const locales = await this.getLocales();

    /**
     * @param {string} locale
     * @return {Promise<[locale: string, assetSource: string]|undefined>}
     */
    const getLocaleAssetsPairs = async (locale) => {
      const data = await this.getTranslationData(keys, locale);
      if (data) {
        return [locale, format(this.options.template, data)];
      }
    };

    const localeAssets = await Promise.all(locales.map(getLocaleAssetsPairs));
    return Object.fromEntries(compact(localeAssets));
  }
}

module.exports = RailsI18nWebpackPlugin;
module.exports.compact = compact;
