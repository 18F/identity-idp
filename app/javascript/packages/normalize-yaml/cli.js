#!/usr/bin/env node

/* eslint-disable no-console */

import { parseArgs } from 'node:util';
import { promises as fsPromises } from 'node:fs';
import { join } from 'node:path';
import prettier from 'prettier';
import normalize from './index.js';

const { readFile, writeFile } = fsPromises;

/** @type {Record<string,any>=} */
const prettierConfig = (await prettier.resolveConfig(process.cwd())) || undefined;

const { values: config, positionals: files } = parseArgs({
  allowPositionals: true,
  options: {
    'disable-collapse-spacing': { type: 'boolean' },
    'disable-sort-keys': { type: 'boolean' },
    'disable-smart-punctuation': { type: 'boolean' },
    'ignore-key-sort': { type: 'string', multiple: true },
  },
});

let ignoreKeySort = config['ignore-key-sort'];
if (ignoreKeySort) {
  ignoreKeySort = ignoreKeySort.flatMap((value) => value.split(','));
}

/** @type {import('./index').NormalizeOptions} */
const options = {
  prettierConfig,
  exclude: /** @type {import('./index').Formatter[]} */ (
    [
      config['disable-collapse-spacing'] && 'collapseSpacing',
      config['disable-sort-keys'] && 'sortKeys',
      config['disable-smart-punctuation'] && 'smartPunctuation',
    ].filter(Boolean)
  ),
  ignoreKeySort,
};

let exitCode = 0;

await Promise.all(
  files.map(async (relativePath) => {
    const absolutePath = join(process.cwd(), relativePath);
    const content = await readFile(absolutePath, 'utf8');
    try {
      await writeFile(absolutePath, await normalize(content, options));
    } catch (error) {
      console.error(`Error normalizing ${relativePath}: ${error.message}`);
      exitCode = 1;
    }
  }),
);

process.exit(exitCode);
