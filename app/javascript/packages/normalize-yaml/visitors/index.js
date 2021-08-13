import formatContent from './format-content.js';
import sortKeys from './sort-keys.js';

/** @typedef {import('yaml').visitor} Visitor */
/** @typedef {'formatContent'|'sortKeys'} Formatter */

/** @type {Record<Formatter, Visitor>} */
const DEFAULT_VISITORS = { formatContent, sortKeys };

/**
 * @param {{ include?: Formatter[] }} include
 *
 * @return {Visitor}
 */
export const getVisitors = ({ include }) =>
  Object.entries(DEFAULT_VISITORS)
    .filter(([formatter]) => !include || include.includes(/** @type {Formatter} */ (formatter)))
    .reduce((result, [, visitor]) => Object.assign(result, visitor), /* @type {Visitor} */ {});
