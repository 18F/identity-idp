#!/usr/bin/env node

/* eslint-disable no-console */

import { watch } from 'chokidar';
import { fileURLToPath } from 'url';
import { buildFile } from './index.js';
import getErrorSassStackPaths from './get-error-sass-stack-paths.js';

/** @typedef {import('sass-embedded').Options<'sync'>} SyncSassOptions */
/** @typedef {import('sass-embedded').Exception} SassException */
/** @typedef {import('./').BuildOptions} BuildOptions */

const env = process.env.NODE_ENV || process.env.RAILS_ENV || 'development';
const isProduction = env === 'production';

const args = process.argv.slice(2);
const fileArgs = args.filter((arg) => !arg.startsWith('-'));
const flags = args.filter((arg) => arg.startsWith('-'));

const isWatching = flags.includes('--watch');
const outDir = flags.find((flag) => flag.startsWith('--out-dir='))?.slice(10);
const loadPaths = flags
  .filter((flag) => flag.startsWith('--load-path='))
  .map((flag) => flag.slice(12));

/** @type {BuildOptions & SyncSassOptions} */
const options = { outDir, loadPaths, optimize: isProduction };

/**
 * Watches given file path(s), triggering the callback on the first change.
 *
 * @param {string|string[]} paths Path(s) to watch.
 * @param {() => void} callback Callback to invoke.
 */
function watchOnce(paths, callback) {
  const watcher = watch(paths).once('change', () => {
    watcher.close();
    callback();
  });
}

/**
 * Returns true if the given error is a SassException, or false otherwise.
 *
 * @param {Error|SassException} error
 *
 * @return {error is SassException}
 */
const isSassException = (error) => 'span' in /** @type {SassException} */ (error);

/**
 * @param {string[]} files
 * @return {Promise<void|void[]>}
 */
function build(files) {
  return Promise.all(
    files.map(async (file) => {
      const { loadedUrls } = await buildFile(file, options);
      if (isWatching) {
        const loadedPaths = loadedUrls.map(fileURLToPath);
        watchOnce(loadedPaths, () => build([file]));
      }
    }),
  ).catch(
    /** @param {Error|SassException} error */ (error) => {
      console.error(error);

      if (isWatching && isSassException(error)) {
        watchOnce(getErrorSassStackPaths(error.sassStack), () => build(files));
      } else {
        throw error;
      }
    },
  );
}

build(fileArgs).catch(() => {
  process.exitCode = 1;
});
