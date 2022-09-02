import YAML from 'yaml';
import prettier from 'prettier';
import { getVisitors } from './visitors/index.js';

/** @typedef {'smartPunctuation'|'sortKeys'} Formatter */

/**
 * @typedef NormalizeOptions
 *
 * @prop {Record<string,any>=} prettierConfig Optional Prettier configuration object.
 * @prop {Array<Formatter>=} exclude Formatters to exclude.
 */

/**
 * @param {string} content Original content.
 * @param {NormalizeOptions} options Normalize options.
 *
 * @return {string} Normalized content.
 */
function normalize(content, { prettierConfig, exclude } = {}) {
  const document = YAML.parseDocument(content);
  YAML.visit(document, getVisitors({ exclude }));
  return prettier.format(document.toString(), { ...prettierConfig, parser: 'yaml' });
}

export default normalize;
