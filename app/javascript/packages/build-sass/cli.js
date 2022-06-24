#!/usr/bin/env node

/* eslint-disable no-console */

import { watch } from 'chokidar';
import { fileURLToPath } from 'url';
import { buildFile } from './index.js';

/** @typedef {import('sass-embedded').Options<'sync'>} SyncSassOptions */
/** @typedef {import('./').BuildOptions} BuildOptions */

const env = process.env.NODE_ENV || process.env.RAILS_ENV || 'development';
const isProduction = env === 'production';

const args = process.argv.slice(2);
const files = args.filter((arg) => !arg.startsWith('-'));
const flags = args.filter((arg) => arg.startsWith('-'));

const isWatching = flags.includes('--watch');
const outDir = flags.find((flag) => flag.startsWith('--out-dir='))?.slice(10);

/** @type {BuildOptions & SyncSassOptions} */
const options = { outDir, optimize: isProduction };

Promise.all(
  files.map(async (file) => {
    const { loadedUrls } = await buildFile(file, options);
    if (isWatching) {
      const loadedPaths = loadedUrls.map(fileURLToPath);
      watch(loadedPaths).on('change', () => buildFile(file, options));
    }
  }),
).catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
