import YAML from 'yaml';
import prettier from 'prettier';
import visitors from './visitors/index.js';

/**
 * @param {string} content Original content.
 * @param {Record<string,any>=} prettierConfig Optional Prettier configuration object.
 *
 * @return {string} Normalized content.
 */
function normalize(content, prettierConfig) {
  const document = YAML.parseDocument(content);
  YAML.visit(document, visitors);
  return prettier.format(document.toString(), { ...prettierConfig, parser: 'yaml' });
}

export default normalize;
