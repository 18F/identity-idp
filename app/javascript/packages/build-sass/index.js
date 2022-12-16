import { basename, join } from 'path';
import { writeFile } from 'fs/promises';
import sass from 'sass-embedded';
import { transform as lightningTransform, browserslistToTargets } from 'lightningcss';
import browserslist from 'browserslist';

/** @typedef {import('sass-embedded').CompileResult} CompileResult */
/** @typedef {import('sass-embedded').Options<'sync'>} SyncSassOptions */

/**
 * @typedef BuildOptions
 *
 * @prop {string=} outDir Output directory.
 * @prop {boolean} optimize Whether to optimize output for production.
 */

const TARGETS = browserslistToTargets(
  browserslist(browserslist.loadConfig({ path: process.cwd() })),
);

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

  let outFile = basename(file, '.scss');

  const lightningResult = lightningTransform({
    filename: outFile,
    code: Buffer.from(sassResult.css),
    minify: optimize,
    targets: TARGETS,
  });

  if (outDir) {
    outFile = join(outDir, outFile);
  }

  await writeFile(outFile, lightningResult.code);

  return sassResult;
}
