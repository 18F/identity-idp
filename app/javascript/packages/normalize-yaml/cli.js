#!/usr/bin/env node
import { promises as fsPromises } from 'fs';
import { join } from 'path';
import prettier from 'prettier';
import normalize from './index.js';

const { readFile, writeFile } = fsPromises;

/** @type {Record<string,any>=} */
const prettierConfig = prettier.resolveConfig.sync(process.cwd());

const files = process.argv.slice(2);
Promise.all(
  files.map(async (relativePath) => {
    const absolutePath = join(process.cwd(), relativePath);
    const content = await readFile(absolutePath, 'utf8');
    await writeFile(absolutePath, normalize(content, prettierConfig));
  }),
);
