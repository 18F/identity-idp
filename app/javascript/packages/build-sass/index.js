import { basename, join } from 'path';
import { writeFile } from 'fs/promises';
import sass from 'sass-embedded';
import postcss from 'postcss';
import autoprefixer from 'autoprefixer';
import cssnano from 'cssnano';

/** @typedef {import('sass-embedded').CompileResult} CompileResult */
/** @typedef {import('sass-embedded').Options<'sync'>} SyncSassOptions */

/**
 * @typedef BuildOptions
 *
 * @prop {string=} outDir Output directory.
 * @prop {boolean} optimize Whether to optimize output for production.
 */

/**
 * Returns the given array with false values omitted.
 *
 * @template A
 *
 * @param {A[]} array
 */
const compact = (array) => /** @type {Array<Exclude<A, false>>} */ (array.filter(Boolean));

/**
 * Compiles a given Sass file.
 *
 * @param {string} file File to build.
 * @param {BuildOptions & SyncSassOptions} options Build options.
 *
 * @return {Promise<CompileResult>}
 */
export async function buildFile(file, options) {
  const { outDir, optimize, ...sassOptions } = options;
  const sassResult = sass.compile(file, {
    style: optimize ? 'compressed' : 'expanded',
    ...sassOptions,
    loadPaths: ['node_modules'],
    quietDeps: true,
  });

  const postcssPlugins = compact([autoprefixer, optimize && cssnano]);
  const postcssResult = await postcss(postcssPlugins).process(sassResult.css, { from: file });

  let outFile = basename(file, '.scss');
  if (outDir) {
    outFile = join(outDir, outFile);
  }

  await writeFile(outFile, postcssResult.css);

  return sassResult;
}
