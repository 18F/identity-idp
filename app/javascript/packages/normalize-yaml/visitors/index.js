import smartPunctuation from './smart-punctuation.js';
import sortKeys from './sort-keys.js';
import collapseSpacing from './collapse-spacing.js';

/** @typedef {import('../').NormalizeOptions} NormalizeOptions */
/** @typedef {(options: NormalizeOptions) => YAMLVisitor} Visitor */
/** @typedef {import('yaml').visitor} YAMLVisitor */
/** @typedef {import('../').Formatter} Formatter */

/** @type {Record<Formatter, Visitor>} */
const DEFAULT_VISITORS = { smartPunctuation, sortKeys, collapseSpacing };

/** @type {(...callbacks: Array<(...args: any[]) => any>) => (...args: any[]) => void} */
const over =
  (...callbacks) =>
  (...args) =>
    callbacks.forEach((callback) => callback(...args));

/**
 * @param {NormalizeOptions} options
 *
 * @return {YAMLVisitor}
 */
export function getUnifiedVisitor(options) {
  const { exclude = [] } = options;
  return Object.entries(DEFAULT_VISITORS)
    .filter(([formatter]) => !exclude.includes(/** @type {Formatter} */ (formatter)))
    .map(([_formatter, visitor]) => visitor)
    .reduce((result, visitor) => {
      const yamlVisitor = visitor(options);
      Object.entries(yamlVisitor).forEach(([key, callback]) => {
        result[key] = result[key] ? over(result[key], callback) : callback;
      });

      return result;
    }, /** @type {YAMLVisitor} */ ({}));
}
