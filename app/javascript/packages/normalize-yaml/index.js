import YAML from 'yaml';
import prettier from 'prettier';
import { getUnifiedVisitor } from './visitors/index.js';

/** @typedef {'smartPunctuation'|'sortKeys'|'collapseSentenceSpacing'} Formatter */

/**
 * @typedef NormalizeOptions
 *
 * @prop {Record<string,any>=} prettierConfig Optional Prettier configuration object.
 * @prop {Array<Formatter>=} exclude Formatters to exclude.
 */

/**
 * Given an input YAML string and optional options, resolves to a normalized YAML string.
 *
 * @param {string} content Original content.
 * @param {NormalizeOptions} options Normalize options.
 *
 * @return {Promise<string>} Normalized content.
 */
function normalize(content, { prettierConfig, exclude } = {}) {
  const document = YAML.parseDocument(content);
  YAML.visit(document, getUnifiedVisitor({ exclude }));
  return prettier.format(document.toString(), { ...prettierConfig, parser: 'yaml' });
}

export default normalize;
