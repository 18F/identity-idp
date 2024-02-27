#!/usr/bin/env node

import { parseArgs } from 'node:util';
import { createWriteStream } from 'node:fs';
import Progress from 'cli-progress';
import Downloader from './downloader.js';
import getLastLine from './get-last-line.js';

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

let linePrefix = '';

/** @type {import('stream').Writable} */
let outputStream;
if (outFile) {
  let offset = 0;

  const lastLine = await getLastLine(outFile);
  const lastHashPrefix = lastLine?.slice(0, 5);
  if (lastHashPrefix && /^[A-Z0-9]+$/.test(lastHashPrefix)) {
    const lastHashOffset = parseInt(lastHashPrefix, 16);
    if (lastHashOffset < parseInt(downloader.rangeEnd, 16)) {
      process.stdout.write(`Resuming from ${lastHashPrefix}…\n`);
      offset = lastHashOffset + 1 - parseInt(downloader.rangeStart, 16);
      downloader.rangeStart = downloader.getRangePath(lastHashOffset + 1);
      outputStream = createWriteStream(outFile, { flags: 'a' });
      linePrefix = '\n';
    }
  }

  outputStream ??= createWriteStream(outFile);

  const progressBar = new Progress.SingleBar({
    fps: 3,
    format: '[{bar}] {percentage}% | ETA {eta_formatted} | {value}/{total}',
  });
  downloader.once('start', ({ total }) => progressBar.start(total + offset, offset));
  downloader.on('download', () => progressBar.increment());
  downloader.once('complete', () => progressBar.stop());
} else {
  outputStream = process.stdout;
}

downloader
  .download()
  .map((line) => `${linePrefix}${line}`)
  .once('data', () => {
    linePrefix = '\n';
  })
  .pipe(outputStream);
