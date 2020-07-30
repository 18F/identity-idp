import { createElement, cloneElement, useContext } from 'react';
import I18nContext from '../context/i18n';

/** @typedef {import('react').FC|import('react').ComponentClass} Component */

/**
 * Given an HTML string and an object of tag names to React component, returns a new of React node
 * where the mapped tag names are replaced by the resulting element of the rendered component.
 *
 * Note that this is a very simplistic interpolation of HTML. It only supports well-balanced, non-
 * nested tag names, where there are no attributes or excess whitespace within the tag names. While
 * the subject markup itself cannot contain attributes, the return value of the component can be any
 * valid React element, with or without additional attributes.
 *
 * @example
 * ```
 * formatHTML('Hello <lg-sparkles>world</lg-sparkles>!', {
 *   'lg-sparkles': ({children}) => <span className="lg-sparkles">{children}</span>
 * });
 * ```
 *
 * @param {string}                   html     HTML to format.
 * @param {Record<string,Component>} handlers Mapping of tag names to components.
 *
 * @return {import('react').ReactNode}
 */
export function formatHTML(html, handlers) {
  const pattern = new RegExp(`</?(?:${Object.keys(handlers).join('|')})>`, 'g');
  const matches = html.match(pattern);
  if (!matches) {
    return html;
  }

  /** @type {Array<import('react').ReactNode>} */
  const parts = html.split(pattern);

  for (let i = 0; i < matches.length; i += 2) {
    const tag = matches[i].slice(1, -1);
    const part = /** @type {string} */ (parts[i + 1]);
    const replacement = createElement(handlers[tag], null, part);
    parts[i + 1] = cloneElement(replacement, { key: part });
  }

  return parts.filter(Boolean);
}

function useI18n() {
  const strings = useContext(I18nContext);

  /**
   * Returns the translated string by the given key.
   *
   * @param {string} key Key to retrieve.
   *
   * @return {string} Translated string.
   */
  const t = (key) => (Object.prototype.hasOwnProperty.call(strings, key) ? strings[key] : key);

  return {
    t,
    formatHTML,
  };
}

export default useI18n;
