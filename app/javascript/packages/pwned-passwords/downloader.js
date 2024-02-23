import EventEmitter from 'node:events';
import https from 'node:https';
import pTimes from 'p-times';
import Flatqueue from 'flatqueue';

/**
 * @typedef DownloadOptions
 *
 * @prop {string} rangeStart Minimum hash prefix for HaveIBeenPwned Range API
 * @prop {string} rangeEnd Inclusive maximum hash prefix for HaveIBeenPwned Range API
 * @prop {number} concurrency Number of parallel downloaders to use to retrieve data
 * @prop {number} maxSize Maximum number of top hashes to retrieve
 */

/**
 * URL prefix for HaveIBeenPwned Range endpoint.
 *
 * @type {string}
 */
const API_ROOT = 'https://api.pwnedpasswords.com/range/';

/**
 * Number of attempts to retry upon failed download for a given range.
 *
 * @type {number}
 */
const MAX_RETRY = 5;

/**
 * Asynchronously yields individual lines received from the given response
 *
 * @param {import('stream').Readable} response
 * @yield {string}
 */
export async function* readLines(response) {
  let data = '';

  for await (const chunk of response) {
    data += chunk.toString();
    const split = data.split('\r\n');
    if (split.length > 1) {
      data = /** @type {string} */ (split.pop());
      yield* split;
    }
  }

  yield data;
}

class Downloader extends EventEmitter {
  /** @type {string} */
  rangeStart;

  /** @type {string} */
  rangeEnd;

  /** @type {number} */
  maxSize;

  /** @type {number} */
  concurrency;

  /** @type {Flatqueue} */
  commonHashes;

  /**
   * @param {Partial<DownloadOptions>} options
   */
  constructor({ rangeStart = '00000', rangeEnd = 'fffff', concurrency = 40, maxSize = 3_000_000 }) {
    super();

    this.rangeStart = rangeStart;
    this.rangeEnd = rangeEnd;
    this.maxSize = maxSize;
    this.concurrency = concurrency;
    this.commonHashes = new Flatqueue();
    this.commonHashes.values = new Uint32Array(maxSize);
  }

  /**
   * Downloads the top password hashes from the configured range and resolves with an iterable
   * object containing all hashes in no particular order.
   *
   * @return {Promise<Iterable<string>>}
   */
  async download() {
    const start = parseInt(this.rangeStart, 16);
    const end = parseInt(this.rangeEnd, 16);
    const total = end - start + 1;
    this.emit('start', { total });
    await pTimes(
      total,
      (index) => this.#downloadRangeWithRetry(this.#getRangePath(start + index)),
      { concurrency: this.concurrency },
    );
    this.emit('complete');

    const { commonHashes } = this;
    return {
      *[Symbol.iterator]() {
        yield* commonHashes.ids;
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
      if (remainingAttempts > 0) {
        await this.#downloadRangeWithRetry(range, remainingAttempts - 1);
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
    const response = await this.#get(url);
    for await (const line of readLines(response)) {
      const [hashSuffix, prevalenceAsString] = line.split(':', 2);
      const prevalence = Number(prevalenceAsString);
      if (this.commonHashes.length >= this.maxSize) {
        if (prevalence > /** @type {number} */ (this.commonHashes.peekValue())) {
          this.commonHashes.pop();
        } else {
          continue;
        }
      }

      const hash = range + hashSuffix;
      this.commonHashes.push(hash, prevalence);
      this.emit('hashchange', {
        hashes: this.commonHashes.length,
        hashMin: this.commonHashes.peekValue(),
      });
    }
  }

  /**
   * Initiates an HTTPS request and resolves with the response
   *
   * @param {URL} url
   * @return {Promise<import('http').IncomingMessage>}
   */
  #get(url) {
    return new Promise((resolve, reject) => {
      https.get(url, resolve).on('error', reject);
    });
  }
}

export default Downloader;
