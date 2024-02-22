#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { pipeline } from 'node:stream/promises';
import { createWriteStream } from 'node:fs';
import { SingleBar } from 'cli-progress';
import { Downloader } from './index.js';

const { values: flags } = parseArgs({
  options: {
    'range-start': { type: 'string' },
    'range-end': { type: 'string' },
    'max-size': { type: 'string' },
    concurrency: { type: 'string' },
    'out-file': { type: 'string' },
  },
});

const {
  'range-start': rangeStart,
  'range-end': rangeEnd,
  'max-size': maxSize,
  concurrency,
  'out-file': outFile,
} = flags;

const downloader = new Downloader({
  rangeStart,
  rangeEnd,
  concurrency: concurrency ? Number(concurrency) : undefined,
  maxSize: maxSize ? Number(maxSize) : undefined,
});

const outputStream = outFile ? createWriteStream(outFile) : process.stdout;

if (outFile) {
  const progressBar = new SingleBar({});
  downloader.once('start', (total) => progressBar.start(total, 0));
  downloader.on('download', () => progressBar.increment());
  downloader.once('complete', () => progressBar.stop());
}

const result = await downloader.download();

await pipeline(
  result,
  async function* (hashPairs) {
    for await (const hashPair of hashPairs) {
      yield `${hashPair.hash}\n`;
    }
  },
  outputStream,
);
