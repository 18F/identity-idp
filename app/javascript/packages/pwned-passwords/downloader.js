import EventEmitter from 'node:events';
import PQueue from 'p-queue';
import PairingHeap from './pairing-heap.js';

/**
 * @typedef DownloadOptions
 *
 * @prop {string} rangeStart Minimum hash prefix for HaveIBeenPwned Range API
 * @prop {string} rangeEnd Inclusive maximum hash prefix for HaveIBeenPwned Range API
 * @prop {number} concurrency Number of parallel downloaders to use to retrieve data
 * @prop {number} maxSize Maximum number of top hashes to retrieve
 */

/**
 * @typedef HashPair
 * @prop {string} hash SHA-1 password hash for common password
 * @prop {number} prevalence Prevalance count within known breaches
 */

/**
 * URL prefix for HaveIBeenPwned Range endpoint.
 */
const API_ROOT = 'https://api.pwnedpasswords.com/range/';

/**
 * Number of attempts to retry upon failed download for a given range.
 */
const MAX_RETRY = 5;

class Downloader extends EventEmitter {
  /** @type {string} */
  rangeStart;

  /** @type {string} */
  rangeEnd;

  /** @type {PQueue} */
  downloaders;

  /** @type {number} */
  maxSize;

  /** @type {PairingHeap<HashPair>} */
  commonHashes = new PairingHeap((a, b) => a.prevalence - b.prevalence);

  /** @type {TextDecoder} */
  decoder = new TextDecoder();

  /**
   * @param {Partial<DownloadOptions>} options
   */
  constructor({ rangeStart = '00000', rangeEnd = 'fffff', concurrency = 40, maxSize = 3_000_000 }) {
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
      this.downloaders.add(() => this.#downloadRangeWithRetry(this.#getRangePath(i)));
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
   * Downloads a given range and appends common password hashes from the response. If the download
   * fails, it is retried corresponding to the number of given remaining attempts.
   *
   * @param {string} range
   * @param {number} remainingAttempts
   */
  async #downloadRangeWithRetry(range, remainingAttempts = MAX_RETRY) {
    try {
      await this.#downloadRange(range);
      this.emit('download');
    } catch (error) {
      if (error.code === 'UND_ERR_SOCKET' && remainingAttempts > 0) {
        this.downloaders.add(() => this.#downloadRangeWithRetry(range, remainingAttempts - 1));
      } else {
        throw error;
      }
    }
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
      const [hashSuffix, prevalenceAsString] = line.split(':', 2);
      const prevalence = Number(prevalenceAsString);
      if (this.commonHashes.length >= this.maxSize) {
        if (prevalence > this.commonHashes.peek().prevalence) {
          this.commonHashes.pop();
        } else {
          continue;
        }
      }

      const hash = range + hashSuffix;
      this.commonHashes.push({ hash, prevalence });
      this.emit('hashchange', {
        hashes: this.commonHashes.length,
        hashMin: this.commonHashes.peek().prevalence,
      });
    }
  }
}

export default Downloader;
