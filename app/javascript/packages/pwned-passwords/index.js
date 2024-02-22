import EventEmitter from 'node:events';
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
   * Downloads the top password hashes from the configured range and resolves with an iterable
   * object containing all hashes in no particular order.
   *
   * @return {Promise<Iterable>}
   */
  async download() {
    const start = parseInt(this.rangeStart, 16);
    const end = parseInt(this.rangeEnd, 16);
    const total = end - start + 1;
    this.emit('start', { total });
    for (let i = start; i <= end; i++) {
      this.downloaders.add(async () => {
        await this.#downloadRange(this.#getRangePath(i));
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
   * Given a number between 0 and 1048575 (16^5 - 1), returns the normalized value to be used as the
   * path suffix for the HaveIBeenPwned range API (a padded, uppercase base16 number).
   *
   * @param {number} value
   * @return {string}
   */
  #getRangePath(value) {
    return value.toString(16).padStart(5, '0').toUpperCase();
  }

  /**
   * Downloads a given range and appends common password hashes from the response.
   *
   * @param {string} range
   */
  async #downloadRange(range) {
    const url = new URL(range, API_ROOT);
    const response = await fetch(url);
    const text = await response.text();
    const lines = text.split('\r\n');
    for await (const line of lines) {
      const hashSuffixOccurrences = line.split(':', 2);
      const occurrences = Number(hashSuffixOccurrences[1]);
      if (this.commonHashes.length >= this.maxSize) {
        if (occurrences > this.commonHashes.peek().occurrences) {
          this.commonHashes.pop();
        } else {
          continue;
        }
      }

      const hashSuffix = hashSuffixOccurrences[0];
      const hash = range + hashSuffix;
      this.commonHashes.push({ hash, occurrences });
      this.emit('hashchange', {
        hashes: this.commonHashes.length,
        hashMin: this.commonHashes.peek().occurrences,
      });
    }
  }
}
