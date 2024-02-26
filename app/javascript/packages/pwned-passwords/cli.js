#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { createWriteStream } from 'node:fs';
import Progress from 'cli-progress';
import Downloader from './downloader.js';

const { values: flags } = parseArgs({
  options: {
    'range-start': { type: 'string' },
    'range-end': { type: 'string' },
    threshold: { type: 'string', short: 't' },
    concurrency: { type: 'string' },
    'out-file': { type: 'string', short: 'o' },
  },
});

const {
  'range-start': rangeStart,
  'range-end': rangeEnd,
  threshold,
  concurrency,
  'out-file': outFile,
} = flags;

const downloader = new Downloader({
  rangeStart,
  rangeEnd,
  concurrency: concurrency ? Number(concurrency) : undefined,
  threshold: threshold ? Number(threshold) : undefined,
});

if (outFile) {
  const progressBar = new Progress.SingleBar({
    fps: 3,
    format: '[{bar}] {percentage}% | ETA {eta_formatted} | {value}/{total} | {hashes} hashes',
  });
  downloader.once('start', ({ total }) => progressBar.start(total, 0, { hashes: 0, hashMin: 0 }));
  downloader.on('download', () => progressBar.increment());
  downloader.once('complete', () => progressBar.stop());
}

const outputStream = outFile ? createWriteStream(outFile) : process.stdout;

let prefix = '';

downloader
  .download()
  .map((line) => `${prefix}${line}`)
  .once('data', () => {
    prefix = '\n';
  })
  .pipe(outputStream);
