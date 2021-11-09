import { useState, useEffect } from 'react';

/**
 * Returns the current document cookie as an object.
 *
 * @return {Record<string, string>}
 */
function getCookieObject() {
  const { cookie } = document;
  return cookie
    .split(';')
    .map((part) => part.trim().split('='))
    .filter(([_key, value]) => typeof value === 'string')
    .reduce((result, [key, value]) => Object.assign(result, { [key]: value }), {});
}

/**
 * React hook to access and manage a cookie value by name.
 *
 * @param {string} name Cookie name.
 *
 * @return {[value: string|null, setValue: (nextValue: string?) => void]}
 */
function useCookie(name) {
  const getCookieValue = () => /** @type {string?} */ (getCookieObject()[name] ?? null);
  const [value, setStateValue] = useState(getCookieValue);

  /**
   * @param {string?} nextValue Value to set, or null to delete the value.
   */
  function setValue(nextValue) {
    const cookieValue = nextValue === null ? '; Max-Age=0' : nextValue;
    document.cookie = `${name}=${cookieValue}`;
    setStateValue(nextValue);
  }

  useEffect(() => {
    const originalCookieDescriptor = Object.getOwnPropertyDescriptor(Document.prototype, 'cookie');
    Object.defineProperty(Document.prototype, 'cookie', {
      ...originalCookieDescriptor,
      set(nextValue) {
        originalCookieDescriptor?.set?.call(this, nextValue);
        setStateValue(getCookieValue);
      },
    });

    return () => {
      Object.defineProperty(
        Document.prototype,
        'cookie',
        /** @type {PropertyDescriptor} */ (originalCookieDescriptor),
      );
    };
  }, []);

  return [value, setValue];
}

export default useCookie;
