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
 * Returns the value in the object at the given key path.
 *
 * @example
 * ```js
 * const value = dig({ a: { b: { c: 'foo' } } }, ['a', 'b', 'c']);
 * // 'foo'
 * ```
 *
 * @param {Record<string, any>} object
 * @param {string[]} keyPath
 *
 * @return {any}
 */
function dig(object, keyPath) {
  let result = object;
  for (const segment of keyPath) {
    if (result == null) {
      return;
    }

    result = result[segment];
  }

  return result;
}

/**
 * Given an array of key-value tuple pairs, returns the corresponding object form.
 *
 * @template V
 *
 * @param {[key: string, value: V][]} pairs
 *
 * @return {Record<string, V>}
 */
const fromPairs = (pairs) =>
  pairs.reduce((result, [key, value]) => ({ ...result, [key]: value }), {});

/**
 * Returns unique values from the given array.
 *
 * @template V
 *
 * @param {V[]} values
 *
 * @returns {V[]}
 */
const uniq = (values) => [...new Set(values)];

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
 * Returns the given key as a path of parts.
 *
 * @param {string} key
 *
 * @return {string[]}
 */
const getKeyPath = (key) => key.split('.');

/**
 * Returns domain for a key string, or split key path.
 *
 * @param {string|string[]} keyOrKeyPath
 *
 * @return {string} The domain.
 */
const getKeyDomain = (keyOrKeyPath) =>
  (Array.isArray(keyOrKeyPath) ? keyOrKeyPath : getKeyPath(keyOrKeyPath))[0];

/**
 * Returns unique domains for the given set of keys.
 *
 * @param {string[]} keys
 *
 * @return {string[]}
 */
const getKeyDomains = (keys) => uniq(keys.map(getKeyDomain));

/**
 * @extends {ExtractKeysWebpackPlugin<RailsI18nWebpackPluginOptions>}
 */
class RailsI18nWebpackPlugin extends ExtractKeysWebpackPlugin {
  /** @type {RailsI18nWebpackPluginOptions} */
  static DEFAULT_OPTIONS = {
    template:
      '!function(){var k,o=%j,l=window._locale_data=window._locale_data||{};for(k in o)l[k]=o[k]}()',
    configPath: path.resolve(process.cwd(), 'config/locales'),
    defaultLocale: 'en',
    onMissingString: () => {},
  };

  /**
   * Cached locale data.
   *
   * @type {{
   *   [domain: string]: {
   *     [locale: string]: Promise<{ [key: string]: string }>
   *   }
   * }}
   */
  localeData = Object.create(null);

  /**
   * Given a translation domain and locale, returns the file path corresponding to locale data.
   *
   * @param {string} domain
   * @param {string} locale
   *
   * @return {string}
   */
  getLocaleFilePath(domain, locale) {
    return path.resolve(this.options.configPath, domain, `${locale}.yml`);
  }

  /**
   * Returns a promise resolving to parsed YAML data for the given domain and locale.
   *
   * @param {string} domain
   * @param {string} locale
   *
   * @return {Promise<Record<string, string>>}
   */
  getLocaleData(domain, locale) {
    if (!(domain in this.localeData)) {
      this.localeData[domain] = Object.create(null);
    }

    if (!(locale in this.localeData[domain])) {
      const localePath = this.getLocaleFilePath(domain, locale);

      this.localeData[domain][locale] = fs
        .readFile(localePath, 'utf-8')
        .then(YAML.parse)
        .catch(() => {});
    }

    return this.localeData[domain][locale];
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
    const keyPath = getKeyPath(key);
    const domain = getKeyDomain(keyPath);
    const localeData = await this.getLocaleData(domain, locale);

    let translation = dig(localeData, [locale, ...keyPath]);
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
   * @param {string} domain
   *
   * @return {Promise<string[]>}
   */
  async getDomainLocales(domain) {
    const localeFiles = await fs.readdir(path.resolve(this.options.configPath, domain));

    return localeFiles
      .filter((file) => file.endsWith('.yml'))
      .map((file) => path.basename(file, '.yml'));
  }

  /**
   * Returns a promise resolving to the unique set of locales for the set of keys.
   *
   * @param {string[]} keys
   *
   * @return {Promise<string[]>}
   */
  async getLocales(keys) {
    const domains = getKeyDomains(keys);
    return uniq((await Promise.all(domains.map((domain) => this.getDomainLocales(domain)))).flat());
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
      return fromPairs(translations);
    }
  }

  async getAdditionalAssets(keys) {
    const locales = await this.getLocales(keys);

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
    return fromPairs(compact(localeAssets));
  }
}

module.exports = RailsI18nWebpackPlugin;
module.exports.dig = dig;
module.exports.fromPairs = fromPairs;
module.exports.uniq = uniq;
module.exports.compact = compact;
module.exports.getKeyPath = getKeyPath;
module.exports.getKeyDomain = getKeyDomain;
module.exports.getKeyDomains = getKeyDomains;
