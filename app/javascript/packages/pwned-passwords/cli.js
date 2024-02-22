#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { pipeline } from 'node:stream/promises';
import { createWriteStream } from 'node:fs';
import Progress from 'cli-progress';
import Downloader from './downloader.js';

const { values: flags } = parseArgs({
  options: {
    'range-start': { type: 'string' },
    'range-end': { type: 'string' },
    'max-size': { type: 'string', short: 'n' },
    concurrency: { type: 'string' },
    'out-file': { type: 'string', short: 'o' },
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
  const progressBar = new Progress.SingleBar({
    format:
      '[{bar}] {percentage}% | ETA {eta_formatted}s | {value}/{total} | {hashes} hashes (>= {hashMin} prevalence)',
  });
  downloader.once('start', ({ total }) => progressBar.start(total, 0, { hashes: 0, hashMin: 0 }));
  downloader.on('download', () => progressBar.increment());
  downloader.on('hashchange', ({ hashes, hashMin }) => progressBar.update({ hashes, hashMin }));
  downloader.once('complete', () => progressBar.stop());
}

const result = await downloader.download();

await pipeline(
  result,
  async function* (hashPairs) {
    let prefix = '';
    for await (const hashPair of hashPairs) {
      yield `${prefix}${hashPair.hash}`;
      prefix ||= '\n';
    }
  },
  outputStream,
);
