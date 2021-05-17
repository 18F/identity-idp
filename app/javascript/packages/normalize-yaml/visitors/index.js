import formatContent from './format-content.js';
import sortKeys from './sort-keys.js';

export default /** @type {import('yaml').visitor} */ ({
  ...formatContent,
  ...sortKeys,
});
