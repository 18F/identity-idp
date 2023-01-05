#!/usr/bin/env node

/* eslint-disable no-console */

import { promises as fsPromises } from 'fs';
import { join } from 'path';
import prettier from 'prettier';
import normalize from './index.js';

const { readFile, writeFile } = fsPromises;

/** @type {Record<string,any>=} */
const prettierConfig = prettier.resolveConfig.sync(process.cwd());

const args = process.argv.slice(2);
const files = args.filter((arg) => !arg.startsWith('-'));
const flags = args.filter((arg) => arg.startsWith('-'));

/** @type {import('./index').NormalizeOptions} */
const options = {
  prettierConfig,
  exclude: /** @type {import('./index').Formatter[]} */ (
    [
      flags.includes('--disable-sort-keys') && 'sortKeys',
      flags.includes('--disable-smart-punctuation') && 'smartPunctuation',
    ].filter(Boolean)
  ),
};

let exitCode = 0;

await Promise.all(
  files.map(async (relativePath) => {
    const absolutePath = join(process.cwd(), relativePath);
    const content = await readFile(absolutePath, 'utf8');
    try {
      await writeFile(absolutePath, normalize(content, options));
    } catch (error) {
      console.error(`Error normalizing ${relativePath}: ${error.message}`);
      exitCode = 1;
    }
  }),
);

process.exit(exitCode);
