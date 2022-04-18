const { Compilation } = require('webpack');

/** @typedef {import('webpack/lib/ChunkGroup')} ChunkGroup */
/** @typedef {import('webpack/lib/Entrypoint')} Entrypoint */

/**
 * Webpack plugin name.
 */
const PLUGIN = 'AssetsWebpackPlugin';

/**
 * Regular expression matching calls to retrieve asset path.
 */
const GET_ASSET_CALL = /getAssetPath(?: \*\/ ?\.[A-Za-z_$]+)?\)?\(\s*['"](.+?)['"]/g;

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
 * @param {string[]} filenames Asset filename.
 * @param {ChunkGroup|Entrypoint} group Chunk group.
 */
const addFilesToEntrypoint = (filenames, group) =>
  typeof group.getEntrypointChunk === 'function'
    ? filenames.forEach((filename) => group.getEntrypointChunk().files.add(filename))
    : group.parentsIterable.forEach((parent) => addFilesToEntrypoint(filenames, parent));

class AssetsWebpackPlugin {
  /**
   * @param {import('webpack').Compiler} compiler
   */
  apply(compiler) {
    compiler.hooks.compilation.tap('compile', (compilation) => {
      compilation.hooks.processAssets.tap(
        { name: PLUGIN, stage: Compilation.PROCESS_ASSETS_STAGE_ADDITIONS },
        () => {
          compilation.chunks.forEach((chunk) => {
            [...chunk.files].filter(isJavaScriptFile).forEach((filename) => {
              const source = compilation.assets[filename].source();
              const assetPaths = getAssetPaths(source);
              if (assetPaths.length) {
                Array.from(chunk.groupsIterable).forEach((group) => {
                  addFilesToEntrypoint(assetPaths, group);
                });
              }
            });
          });
        },
      );
    });
  }
}

module.exports = AssetsWebpackPlugin;
module.exports.getAssetPaths = getAssetPaths;
