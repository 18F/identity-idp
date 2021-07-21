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
 * Given an original file name and suffix, returns a modified file name with the suffix injected
 * prior to the original file extension.
 *
 * @param {string} filename
 * @param {string} suffix
 *
 * @return {string}
 */
function getAdditionalAssetFilename(filename, suffix) {
  const parts = filename.split('.');
  parts.splice(parts.length - 1, 0, suffix);
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
 * Given a Webpack chunk, returns true if the chunk is for a JavaScript entry module, or false
 * otherwise.
 *
 * @param {import('webpack').Chunk} chunk
 *
 * @return {boolean}
 */
const isJavaScriptChunk = (chunk) => !!chunk.entryModule?.type.startsWith('javascript/');

/**
 * @template {Record<string,any>} Options
 */
class ExtractKeysWebpackPlugin {
  static DEFAULT_OPTIONS = {};

  /**
   * @param {Options=} options
   */
  constructor(options) {
    const { DEFAULT_OPTIONS } = /** @type {typeof ExtractKeysWebpackPlugin} */ (this.constructor);

    this.options = /** @type {Options} */ (Object.keys(DEFAULT_OPTIONS).reduce((result, key) => {
      result[key] = options?.[key] ?? DEFAULT_OPTIONS[key];
      return result;
    }, {}));
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
          compilation.chunks.filter(isJavaScriptChunk).map((chunk) =>
            Promise.all(
              chunk.files.map(async (filename) => {
                const source = compilation.assets[filename].source();
                const keys = getTranslationKeys(source);
                const additionalAssets = await this.getAdditionalAssets(keys);
                for (const [suffix, content] of Object.entries(additionalAssets)) {
                  const assetFilename = getAdditionalAssetFilename(filename, suffix);
                  compilation.emitAsset(assetFilename, new sources.RawSource(content));
                  chunk.files.push(assetFilename);
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
module.exports.isJavaScriptChunk = isJavaScriptChunk;
