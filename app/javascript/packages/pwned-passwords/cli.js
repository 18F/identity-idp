#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { Downloader } from './index.js';

const { values: flags } = parseArgs({
  options: {
    'range-start': { type: 'string' },
    'range-end': { type: 'string' },
    'max-size': { type: 'string' },
    concurrency: { type: 'string' },
  },
});

const {
  'range-start': rangeStart,
  'range-end': rangeEnd,
  'max-size': maxSize,
  concurrency,
} = flags;

const result = await new Downloader({
  rangeStart,
  rangeEnd,
  concurrency: concurrency ? Number(concurrency) : undefined,
  maxSize: maxSize ? Number(maxSize) : undefined,
}).download();

await pipeline(
  Readable.from(result),
  async function* (hashPairs) {
    for await (const hashPair of hashPairs) {
      yield `${hashPair.hash}\n`;
    }
  },
  process.stdout,
);
