import base32Decode from 'base32-decode';
import base32Encode from 'base32-encode';

export function encodeInput(value) {
  // Coerce mistaken user input from 'problem' letters:
  // https://en.wikipedia.org/wiki/Base32#Crockford.27s_Base32
  value = value.replace(/-/g, '');
  value = base32Decode(value, 'Crockford');
  value = base32Encode(value, 'Crockford');

  // Add back the dashes
  value = value.toString().match(/.{4}/g).join('-');

  // And uppercase
  return value.toUpperCase();
}
