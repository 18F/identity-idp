import formatContent from './format-content.js';
import sortKeys from './sort-keys.js';

/** @typedef {import('yaml').visitor} Visitor */
/** @typedef {import('../').Formatter} Formatter */

/** @type {Record<Formatter, Visitor>} */
const DEFAULT_VISITORS = { formatContent, sortKeys };

/**
 * @param {{ exclude?: Formatter[] }} exclude
 *
 * @return {Visitor}
 */
export const getVisitors = ({ exclude = [] }) =>
  Object.entries(DEFAULT_VISITORS)
    .filter(([formatter]) => !exclude.includes(/** @type {Formatter} */ (formatter)))
    .reduce((result, [, visitor]) => Object.assign(result, visitor), /* @type {Visitor} */ {});
