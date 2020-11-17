import base32Decode from 'base32-decode';
import base32Encode from 'base32-encode';

/**
 * Coerce mistaken user input from 'problem' letters:
 * https://en.wikipedia.org/wiki/Base32#Crockford.27s_Base32
 *
 * @param {string} value User-provided text input
 *
 * @return {string} Encoded input
 */
export function encodeInput(value) {
  value = value.replace(/-/g, '');
  value = base32Encode(base32Decode(value, 'Crockford'), 'Crockford');

  // Add back the dashes
  value = (value.match(/.{4}/g) || [value]).join('-');

  // And uppercase
  return value.toUpperCase();
}
