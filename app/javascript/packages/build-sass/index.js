import { basename, join } from 'node:path';
import { createWriteStream } from 'node:fs';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { compile as sassCompile } from 'sass-embedded';
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
  const { outDir, optimize, loadPaths = [], ...sassOptions } = options;
  const sassResult = sassCompile(file, {
    style: optimize ? 'compressed' : 'expanded',
    ...sassOptions,
    loadPaths: [...loadPaths, 'node_modules'],
    quietDeps: true,
  });

  let outFile = `${basename(basename(file, '.css.scss'), '.scss')}.css`;

  const lightningResult = lightningTransform({
    filename: outFile,
    code: Buffer.from(sassResult.css),
    minify: optimize,
    targets: TARGETS,
  });

  if (outDir) {
    outFile = join(outDir, outFile);
  }

  await pipeline(Readable.from(lightningResult.code), createWriteStream(outFile));

  return sassResult;
}
