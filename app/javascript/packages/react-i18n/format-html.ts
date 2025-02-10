import { createElement } from 'react';
import type { ComponentClass, FunctionComponent, ReactNode } from 'react';

type Handlers = Record<string, ComponentClass | FunctionComponent | string>;

/**
 * Given an HTML string and an object of tag names to React component, returns a new React node
 * where the mapped tag names are replaced by the resulting element of the rendered component.
 *
 * Note that this is a very simplistic interpolation of HTML. It only supports self-closing and
 * well-balanced, non-nested tag names, where there are no attributes or excess whitespace within
 * the tag names. The tag name cannot contain regular expression special characters.
 *
 * While the subject markup itself cannot contain attributes, the return value of the component can
 * be any valid React element, with or without additional attributes.
 *
 * @example
 * ```
 * formatHTML('Hello <lg-sparkles>world</lg-sparkles>!', {
 *   'lg-sparkles': ({children}) => <span className="lg-sparkles">{children}</span>
 * });
 * ```
 *
 * @param html HTML to format.
 * @param handlers Mapping of tag names to tag name or component.
 */
function formatHTML(html: string, handlers: Handlers): ReactNode {
  const pattern = new RegExp(`</?(?:${Object.keys(handlers).join('|')})(?: .*?)?/?>`, 'g');
  const matches = html.match(pattern);
  if (!matches) {
    return html;
  }

  const parts: Array<string | ReactNode> = html.split(pattern);

  // Count spliced insertions to use as an offset when replacing parts, since the subsequent loop's
  // iterator is based on matches and the original parts array.
  let spliceCount = 0;

  for (let i = 0; i < matches.length; i++) {
    const match = matches[i];
    const end = match.search(/ |\/?>/);
    const tag = matches[i].slice(1, end);
    const key = `part${i}`;
    const isSelfClosing = match.endsWith('/>');

    if (isSelfClosing) {
      const replacement = createElement(handlers[tag], { key });
      parts.splice(i + spliceCount + 1, 0, replacement);
      spliceCount++;
    } else {
      const part = parts[i + spliceCount + 1] as string;
      const replacement = createElement(handlers[tag], { key }, part);
      parts[i + spliceCount + 1] = replacement;
      i++; // Increment to skip the closing tag
    }
  }

  return parts.filter(Boolean);
}

export default formatHTML;
