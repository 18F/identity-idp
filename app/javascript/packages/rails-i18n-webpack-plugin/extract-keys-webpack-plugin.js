const sources = require('webpack-sources');

/**
 * Webpack plugin name.
 *
 * @type {string}
 */
const PLUGIN = 'ExtractKeysWebpackPlugin';

/**
 * Regular expression matching translation calls.
 *
 * @see https://github.com/glebm/i18n-tasks/blob/v0.9.34/lib/i18n/tasks/scanners/pattern_scanner.rb#L15
 *
 * @type {RegExp}
 */
const TRANSLATE_CALL = /(?:^|[^\w'-])(?:I18n\.)?t\(\s*['"](.+?)['"]/g;

/**
 * Given an original file name and locale, returns a modified file name with the locale injected
 * prior to the original file extension.
 *
 * @param {string} filename
 * @param {string} locale
 *
 * @return {string}
 */
function getAdditionalAssetFilename(filename, locale) {
  const parts = filename.split('.');
  parts.splice(parts.length - 1, 0, locale);
  return parts.join('.');
}

/**
 * Given a string of source code, returns occurrences of translation keys.
 *
 * @param source Source code.
 *
 * @return {string[]} Translation keys.
 */
const getTranslationKeys = (source) =>
  Array.from(source.matchAll(TRANSLATE_CALL)).map(([, key]) => key);

/**
 * Given a file name, returns true if the file is a JavaScript file, or false otherwise.
 *
 * @param {string} filename
 *
 * @return {boolean}
 */
const isJavaScriptFile = (filename) => filename.endsWith('.js');

/**
 * @template {Record<string,any>} Options
 */
class ExtractKeysWebpackPlugin {
  static DEFAULT_OPTIONS = {};

  /**
   * @param {Options=} options
   */
  constructor(options = /** @type {Partial<Options>} */ ({})) {
    const { DEFAULT_OPTIONS } = /** @type {typeof ExtractKeysWebpackPlugin} */ (this.constructor);

    this.options = /** @type {Options} */ ({ ...DEFAULT_OPTIONS, ...options });
  }

  /**
   * @param {string[]} _keys
   *
   * @return {Promise<Record<string, string>>}
   */
  getAdditionalAssets(_keys) {
    return Promise.resolve({});
  }

  apply(compiler) {
    compiler.hooks.compilation.tap('compile', (compilation) => {
      compilation.hooks.additionalAssets.tapPromise(PLUGIN, () =>
        Promise.all(
          [...compilation.chunks].map((chunk) =>
            Promise.all(
              [...chunk.files].filter(isJavaScriptFile).map(async (filename) => {
                const source = compilation.assets[filename].source();
                const keys = getTranslationKeys(source);
                const additionalAssets = await this.getAdditionalAssets(keys);
                for (const [locale, content] of Object.entries(additionalAssets)) {
                  const assetFilename = getAdditionalAssetFilename(filename, locale);
                  compilation.emitAsset(assetFilename, new sources.RawSource(content));
                  chunk.files.add(assetFilename);
                }
              }),
            ),
          ),
        ),
      );
    });
  }
}

module.exports = ExtractKeysWebpackPlugin;
module.exports.getAdditionalAssetFilename = getAdditionalAssetFilename;
module.exports.getTranslationKeys = getTranslationKeys;
module.exports.isJavaScriptFile = isJavaScriptFile;
