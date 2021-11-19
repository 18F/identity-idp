import smartquotes from 'smartquotes';

/**
 * @param {string} html String potentially containing HTML.
 * @param {(substring: string) => string} replacer Replacer function given content between non-tag
 * content to replace.
 *
 * @return {string}
 */
export function replaceInHTMLContent(html, replacer) {
  return html.replace(
    /([^<]*)(<.*?>)?/g,
    (_match, text, tag = '') => (text ? replacer(text) : text) + tag,
  );
}

/**
 * Replaces any instance of three dot characters with single ellipsis characters.
 *
 * @param {string} string
 *
 * @return {string}
 */
export const ellipses = (string) => string.replace(/\.\.\./g, '…');

export default /** @type {import('yaml').visitor} */ ({
  Scalar(_key, node) {
    if (typeof node.value === 'string') {
      node.value = replaceInHTMLContent(node.value, (string) => ellipses(smartquotes(string)));
    }
  },
});
