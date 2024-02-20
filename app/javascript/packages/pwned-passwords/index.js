/* eslint-disable no-unreachable */
import EventEmitter from 'node:events';
// eslint-disable-next-line import/no-unresolved
import PQueue from 'p-queue';
import PairingHeap from './pairing-heap.js';

/**
 * @typedef DownloadOptions
 *
 * @prop {string} rangeStart
 * @prop {string} rangeEnd
 * @prop {number} concurrency
 * @prop {number} maxSize
 */

/**
 * @typedef HashPair
 * @prop {string} hash
 * @prop {number} occurrences
 */

const API_ROOT = 'https://api.pwnedpasswords.com/range/';

export class Downloader extends EventEmitter {
  /** @type {string} */
  rangeStart;

  /** @type {string} */
  rangeEnd;

  /** @type {PQueue} */
  downloaders;

  /** @type {number} */
  maxSize;

  /** @type {PairingHeap<HashPair>} */
  commonHashes = new PairingHeap((a, b) => a.occurrences - b.occurrences);

  /** @type {TextDecoder} */
  decoder = new TextDecoder();

  /**
   * @param {Partial<DownloadOptions>} options
   */
  constructor({ rangeStart = '5ba42', rangeEnd = '5bb0a', concurrency = 40, maxSize = 300 }) {
    super();

    this.rangeStart = rangeStart;
    this.rangeEnd = rangeEnd;
    this.maxSize = maxSize;
    this.downloaders = new PQueue({ concurrency });
  }

  /**
   * @return {Promise<Iterable>}
   */
  async download() {
    const start = parseInt(this.rangeStart, 16);
    const end = parseInt(this.rangeEnd, 16);
    const total = end - start + 1;
    this.emit('start', total);
    for (let i = start; i <= end; i++) {
      this.downloaders.add(async () => {
        await this.downloadRange(this.getPaddedRange(i));
        this.emit('download');
      });
    }

    await this.downloaders.onIdle();
    this.emit('complete');

    const { commonHashes } = this;
    return {
      *[Symbol.iterator]() {
        yield* commonHashes;
      },
    };
  }

  /**
   * @param {number} value
   * @return {string}
   */
  getPaddedRange(value) {
    return value.toString(16).padStart(5, '0').toUpperCase();
  }

  /** @param {string} range */
  async downloadRange(range) {
    const url = new URL(range, API_ROOT);
    const { body } = await fetch(url);
    for await (const line of this.readLines(body)) {
      const hashSuffixOccurrences = line.split(':', 2);
      const occurrences = Number(hashSuffixOccurrences[1]);
      if (this.commonHashes.length >= this.maxSize) {
        if (occurrences > this.commonHashes.peek().occurrences) {
          this.commonHashes.pop();
        } else {
          // eslint-disable-next-line no-continue
          continue;
        }
      }

      const hashSuffix = hashSuffixOccurrences[0];
      const hash = range + hashSuffix;
      this.commonHashes.push({ hash, occurrences });
    }
  }

  /**
   * @param {Response['body']} body
   */
  async *readLines(body) {
    if (!body) {
      return;
    }

    let data = '';

    // @ts-ignore
    for await (const chunk of body) {
      const [appended, ...lines] = this.decoder.decode(chunk).split('\r\n');
      if (lines.length) {
        const nextData = /** @type {string} */ (lines.pop());
        yield data + appended;
        yield* lines;
        data = nextData;
      } else {
        data += appended;
      }
    }
  }
}
