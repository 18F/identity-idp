import smartPunctuation from './smart-punctuation.js';
import sortKeys from './sort-keys.js';
import collapseSentenceSpacing from './collapse-sentence-spacing.js';

/** @typedef {import('yaml').visitor} Visitor */
/** @typedef {import('../').Formatter} Formatter */

/** @type {Record<Formatter, Visitor>} */
const DEFAULT_VISITORS = { smartPunctuation, sortKeys, collapseSentenceSpacing };

/** @type {(...callbacks: Array<(...args: any[]) => any>) => (...args: any[]) => void} */
const over =
  (...callbacks) =>
  (...args) =>
    callbacks.forEach((callback) => callback(...args));

/**
 * @param {{ exclude?: Formatter[] }} exclude
 *
 * @return {Visitor}
 */
export const getUnifiedVisitor = ({ exclude = [] }) =>
  Object.entries(DEFAULT_VISITORS)
    .filter(([formatter]) => !exclude.includes(/** @type {Formatter} */ (formatter)))
    .map(([_formatter, visitor]) => visitor)
    .reduce((result, visitor) => {
      Object.entries(visitor).forEach(([key, callback]) => {
        result[key] = result[key] ? over(result[key], callback) : callback;
      });

      return result;
    }, /** @type {Visitor} */ ({}));
