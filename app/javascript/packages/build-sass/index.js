import { basename, join, dirname } from 'node:path';
import { createWriteStream } from 'node:fs';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { compileAsync as baseSassCompileAsync } from 'sass-embedded';
import { transform as lightningTransform, browserslistToTargets } from 'lightningcss';
import browserslist from 'browserslist';

/** @typedef {import('sass-embedded').AsyncCompiler} AsyncCompiler */
/** @typedef {import('sass-embedded').CompileResult} CompileResult */
/** @typedef {import('sass-embedded').Options<'sync'>} SyncSassOptions */

/**
 * @typedef BuildOptions
 *
 * @prop {string=} outDir Output directory.
 * @prop {boolean} optimize Whether to optimize output for production.
 * @prop {AsyncCompiler=} sassCompiler Sass compiler to use, particularly useful with initCompiler
 */

const TARGETS = browserslistToTargets(
  browserslist(browserslist.loadConfig({ path: process.cwd() })),
);

/**
 * Compiles a given Sass file.
 *
 * @param {string} file File to build.
 * @param {Partial<BuildOptions> & SyncSassOptions} options Build options.
 *
 * @return {Promise<CompileResult>}
 */
export async function buildFile(file, options) {
  const {
    outDir = dirname(file),
    optimize,
    loadPaths = [],
    sassCompiler,
    ...sassOptions
  } = options;
  const sassCompile = sassCompiler
    ? sassCompiler.compileAsync.bind(sassCompiler)
    : baseSassCompileAsync;

  const sassResult = await sassCompile(file, {
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

  outFile = join(outDir, outFile);

  await pipeline(Readable.from(lightningResult.code), createWriteStream(outFile));

  return sassResult;
}
