/**
 * Naive implementation of converting string to dash-delimited string, targeting support only for
 * alphanumerical strings.
 *
 * @example
 * ```
 * kebabCase('HelloWorld');
 * // 'hello-world'
 * ```
 *
 * @param {string} string
 *
 * @return {string}
 */
const kebabCase = (string) => string.replace(/(.)([A-Z])/g, '$1-$2').toLowerCase();

/**
 * Returns data- attribute selector associated with a given dataset key.
 *
 * @param {string} key Dataset key.
 *
 * @return {string} Data attribute.
 */
const getDataAttributeSelector = (key) => `[data-${kebabCase(key)}]`;

/**
 * Returns the value associated with a page element with the given dataset property, or undefined if
 * the element does not exist.
 *
 * @param {string} key Key for which to return value.
 *
 * @return {string=} Value, if exists.
 */
export function getPageData(key) {
  const element = document.querySelector(getDataAttributeSelector(key));
  return /** @type {HTMLElement=} */ (element)?.dataset[key];
}
