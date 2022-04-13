const { Compilation } = require('webpack');
const { RawSource } = require('webpack-sources');

/** @typedef {import('webpack/lib/ChunkGroup')} ChunkGroup */
/** @typedef {import('webpack/lib/Entrypoint')} Entrypoint */

/**
 * Webpack plugin name.
 */
const PLUGIN = 'AssetsWebpackPlugin';

/**
 * Regular expression matching calls to retrieve asset path.
 */
const GET_ASSET_CALL = /getAssetPath\)?\(\s*['"](.+?)['"]/g;

/**
 * Given a file name, returns true if the file is a JavaScript file, or false otherwise.
 *
 * @param {string} filename
 *
 * @return {boolean}
 */
const isJavaScriptFile = (filename) => filename.endsWith('.js');

/**
 * Given a string of source code, returns array of asset paths.
 *
 * @param source Source code.
 *
 * @return {string[]} Asset paths.
 */
const getAssetPaths = (source) =>
  Array.from(source.matchAll(GET_ASSET_CALL)).map(([, path]) => path);

/**
 * Adds the given asset file name to the list of files of the group's parent entrypoint.
 *
 * @param {ChunkGroup|Entrypoint} group Chunk group.
 */
const getEntrypointChunk = (group) =>
  typeof group.getEntrypointChunk === 'function'
    ? group.getEntrypointChunk()
    : Array.from(group.parentsIterable).find((parent) => getEntrypointChunk(parent));

class AssetsWebpackPlugin {
  /**
   * @param {import('webpack').Compiler} compiler
   */
  apply(compiler) {
    compiler.hooks.compilation.tap('compile', (compilation) => {
      compilation.hooks.processAssets.tap(
        { name: PLUGIN, stage: Compilation.PROCESS_ASSETS_STAGE_ADDITIONAL },
        () => {
          const chunkAssets = /** @type {Map<string, Set<string>>} */ (new Map());

          compilation.chunks.forEach((chunk) => {
            [...chunk.files].filter(isJavaScriptFile).forEach((filename) => {
              const source = compilation.assets[filename].source();
              const assetPaths = getAssetPaths(source);
              if (!assetPaths.length) {
                return;
              }

              Array.from(chunk.groupsIterable).forEach((group) => {
                const { name } = getEntrypointChunk(group);
                if (!chunkAssets.has(name)) {
                  chunkAssets.set(name, new Set());
                }

                const assets = /** @type {Set<string>} */ (chunkAssets.get(name));
                assetPaths.forEach((assetPath) => assets.add(assetPath));
              });
            });
          });

          const manifest = JSON.stringify(chunkAssets, (_key, value) => {
            if (value instanceof Map) {
              return Object.fromEntries(value);
            }

            if (value instanceof Set) {
              return Array.from(value);
            }

            return value;
          });

          compilation.emitAsset('_assets.json', new RawSource(manifest));
        },
      );
    });
  }
}

module.exports = AssetsWebpackPlugin;
