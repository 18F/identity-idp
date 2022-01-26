import { basename, join } from 'path';
import { writeFile } from 'fs/promises';
import { compile } from 'sass-embedded';

/** @typedef {import('sass-embedded').CompileResult} CompileResult */
/** @typedef {import('sass-embedded').Options<'sync'>} SyncSassOptions */

/**
 * @typedef BuildOptions
 *
 * @prop {string=} outDir Output directory.
 */

/**
 * Compiles a given Sass file.
 *
 * @param {string} file File to build.
 * @param {BuildOptions & SyncSassOptions} options Build options.
 *
 * @return {Promise<CompileResult>}
 */
export async function buildFile(file, options) {
  const { outDir, ...sassOptions } = options;
  const compileResult = compile(file, {
    ...sassOptions,
    loadPaths: ['node_modules'],
    quietDeps: true,
  });

  let outFile = basename(file, '.scss');
  if (outDir) {
    outFile = join(outDir, outFile);
  }

  await writeFile(outFile, compileResult.css);

  return compileResult;
}
