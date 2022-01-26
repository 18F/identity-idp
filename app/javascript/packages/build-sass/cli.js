#!/usr/bin/env node

import { watch } from 'chokidar';
import { fileURLToPath } from 'url';
import { buildFile } from './index.js';

/** @typedef {import('sass-embedded').CompileResult} CompileResult */
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
const options = { outDir, style: isProduction ? 'compressed' : 'expanded' };

const build = Promise.all(
  files.map(
    async (file) => /** @type {[string, CompileResult]} */ ([file, await buildFile(file, options)]),
  ),
);

if (isWatching) {
  build.then((results) => {
    for (const [file, compileResult] of results) {
      const loadedPaths = compileResult.loadedUrls.map(fileURLToPath);
      watch(loadedPaths).on('change', () => buildFile(file, options));
    }
  });
}
