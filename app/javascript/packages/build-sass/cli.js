#!/usr/bin/env node

/* eslint-disable no-console */

import { mkdir } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { watch } from 'chokidar';
import { fileURLToPath } from 'url';
import { buildFile } from './index.js';
import getDefaultLoadPaths from './get-default-load-paths.js';
import getErrorSassStackPaths from './get-error-sass-stack-paths.js';

/** @typedef {import('sass-embedded').Options<'sync'>} SyncSassOptions */
/** @typedef {import('sass-embedded').Exception} SassException */
/** @typedef {import('./').BuildOptions} BuildOptions */

const env = process.env.NODE_ENV || process.env.RAILS_ENV || 'development';
const isProduction = env === 'production';

const { values: flags, positionals: fileArgs } = parseArgs({
  allowPositionals: true,
  options: {
    watch: { type: 'boolean' },
    'out-dir': { type: 'string' },
    'load-path': { type: 'string', multiple: true, default: [] },
  },
});

const { watch: isWatching, 'out-dir': outDir, 'load-path': loadPaths = [] } = flags;
loadPaths.push(...getDefaultLoadPaths());

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

mkdir(outDir, { recursive: true })
  .then(() => build(fileArgs))
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
