import PQueue from 'p-queue';
import { PairingHeap } from '@thi.ng/heaps';

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

export class Downloader {
  /** @type {string} */
  rangeStart;

  /** @type {string} */
  rangeEnd;

  /** @type {PQueue} */
  downloaders;

  /** @type {number} */
  maxSize;

  /** @type {PairingHeap<HashPair>} */
  commonHashes;

  /**
   * @param {Partial<DownloadOptions>} options
   */
  constructor({ rangeStart = '00000', rangeEnd = '00000', concurrency = 40, maxSize = 30 }) {
    this.rangeStart = rangeStart;
    this.rangeEnd = rangeEnd;
    this.maxSize = maxSize;
    this.downloaders = new PQueue({ concurrency });
    this.commonHashes = new PairingHeap(undefined, { compare: this.compareHashPair });
  }

  /**
   * @param {HashPair} a
   * @param {HashPair} b
   * @return {number}
   */
  compareHashPair(a, b) {
    return a.occurrences - b.occurrences;
  }

  download() {
    const start = parseInt(this.rangeStart, 16);
    const end = parseInt(this.rangeEnd, 16);
    for (let i = start; i <= end; i++) {
      this.downloaders.add(() => this.downloadRange(this.getPaddedRange(i)));
    }

    return new Promise((resolve) => {
      this.downloaders.on('completed', () => {
        /**
         * @type {PairingHeap<string>}
         */
        const sortedHashes = new PairingHeap(undefined, { compare: (a, b) => a.localeCompare(b) });
        for (const hashPair of this.commonHashes) {
          sortedHashes.push(hashPair.hash);
        }
        resolve(function* readHashes() {
          yield* sortedHashes;
        });
      });
    });
  }

  /**
   * @param {number} value
   * @return {string}
   */
  getPaddedRange(value) {
    return value.toString(16).padStart(5, '0');
  }

  /** @param {string} range */
  async downloadRange(range) {
    const url = new URL(range, API_ROOT);
    const { body } = await fetch(url);
    for await (const line of this.readLines(body)) {
      const hashSuffixOccurrences = line.split(':');
      const occurrences = Number(hashSuffixOccurrences[1]);
      if (this.commonHashes.length > this.maxSize) {
        if (occurrences > /** @type {HashPair} */ (this.commonHashes.peek()).occurrences) {
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
      const [appended, ...lines] = new TextDecoder().decode(chunk).split('\r\n');
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
