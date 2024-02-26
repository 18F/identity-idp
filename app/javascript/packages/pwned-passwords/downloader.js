import EventEmitter from 'node:events';
import { Readable } from 'node:stream';

/**
 * @typedef DownloadOptions
 *
 * @prop {string} rangeStart Minimum hash prefix for HaveIBeenPwned Range API
 * @prop {string} rangeEnd Inclusive maximum hash prefix for HaveIBeenPwned Range API
 * @prop {number} concurrency Number of parallel downloaders to use to retrieve data
 * @prop {number} maxRetry Number of attempts to retry upon failed download for a given range
 * @prop {number} threshold Minimum prevalance count to pick from ranges
 */

/**
 * @typedef HashPair
 * @prop {string} hash SHA-1 password hash for common password
 * @prop {number} prevalence Prevalance count within known breaches
 */

/**
 * URL prefix for HaveIBeenPwned Range endpoint.
 *
 * @type {string}
 */
const API_ROOT = 'https://api.pwnedpasswords.com/range/';

function* createIterableRange(start, end) {
  for (let i = start; i <= end; i++) {
    yield i;
  }
}

class Downloader extends EventEmitter {
  /** @type {string} */
  rangeStart;

  /** @type {string} */
  rangeEnd;

  /** @type {number} */
  concurrency;

  /** @type {number} */
  threshold;

  /**
   * @param {Partial<DownloadOptions>} options
   */
  constructor({
    rangeStart = '00000',
    rangeEnd = 'fffff',
    concurrency = 40,
    maxRetry = 5,
    threshold = 20,
  }) {
    super();

    this.rangeStart = rangeStart;
    this.rangeEnd = rangeEnd;
    this.maxRetry = maxRetry;
    this.concurrency = concurrency;
    this.threshold = threshold;
  }

  /**
   * Downloads the top password hashes from the configured range and resolves with an iterable
   * object containing all hashes in no particular order.
   *
   * @return {import('stream').Readable}
   */
  download() {
    const { rangeStart, rangeEnd, concurrency, threshold } = this;
    const start = parseInt(rangeStart, 16);
    const end = parseInt(rangeEnd, 16);
    const total = end - start + 1;
    this.emit('start', { total });

    return Readable.from(createIterableRange(start, end))
      .flatMap((i) => this.#downloadRangeWithRetry(this.#getRangePath(i)), { concurrency })
      .filter((line) => this.#getPrevalence(line) >= threshold)
      .on('end', () => this.emit('complete'));
  }

  #getPrevalence(line) {
    return Number(line.slice(41));
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
   *
   * @return {Promise<string[]>}
   */
  async #downloadRangeWithRetry(range, remainingAttempts = this.maxRetry) {
    try {
      const lines = await this.#downloadRange(range);
      this.emit('download');
      return lines;
    } catch (error) {
      if (remainingAttempts > 0) {
        return this.#downloadRangeWithRetry(range, remainingAttempts - 1);
      }

      throw error;
    }
  }

  /**
   * Downloads a given range and appends common password hashes from the response.
   *
   * @param {string} range
   *
   * @return {Promise<string[]>}
   */
  async #downloadRange(range) {
    const url = new URL(range, API_ROOT);
    const response = await fetch(url);
    const text = await response.text();
    return text.split('\r\n').map((suffix) => range + suffix);
  }
}

export default Downloader;
