import { useState, useEffect } from 'react';

/**
 * Given a query string and parameter name, returns the decoded value associated with that parameter
 * in the query string, or null if the value cannot be found. The query string should be provided
 * without a leading "?".
 *
 * This is intended to polyfill a behavior equivalent to:
 *
 * ```
 * new URLSearchParams(queryString).get(name)
 * ```
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/URLSearchParams/get
 *
 * @param {string} queryString Query string to search within.
 * @param {string} name        Parameter name to search for.
 *
 * @return {?string} Decoded parameter value if found, or null otherwise.
 */
export function getQueryParam(queryString, name) {
  const pairs = queryString.split('&');
  for (let i = 0; i < pairs.length; i += 1) {
    const [key, value = ''] = pairs[i].split('=').map(decodeURIComponent);
    if (key === name) return value;
  }

  return null;
}

/**
 * Scrolls the page to the given set of X and Y coordinates. Progressively enhances to use smooth
 * scrolling if supported.
 *
 * @param {number} left Left (X) coordinate.
 * @param {number} top  Top (Y) coordinate.
 */
function scrollTo(left, top) {
  try {
    window.scrollTo({ left, top, behavior: 'smooth' });
  } catch {
    window.scrollTo(left, top);
  }
}

/**
 * Returns a hook which syncs a querystring parameter by the given name using History pushState.
 * Returns a `useState`-like tuple of the current value and a setter to assign the next parameter
 * value.
 *
 * The current implementation is limited to managing at most one query parameter at a time for the
 * entire application.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/History/pushState
 *
 * @param {string} name Parameter name to sync.
 *
 * @return {[any,(nextParamValue:any)=>void]} Tuple of current state, state setter.
 */
function useHistoryParam(name) {
  const getCurrentQueryParam = () =>
    getQueryParam(window.location.hash.slice(1), name) ?? undefined;

  const [value, setValue] = useState(getCurrentQueryParam);

  function setParamValue(nextValue) {
    const nextURL = nextValue
      ? `#${[name, nextValue].map(encodeURIComponent).join('=')}`
      : window.location.pathname + window.location.search;

    // Push the next value to history, both to update the URL, and to allow the user to return to
    // an earlier value (see `popstate` sync behavior).
    window.history.pushState(null, null, nextURL);

    scrollTo(0, 0);

    setValue(nextValue);
  }

  useEffect(() => {
    function syncValue() {
      setValue(getCurrentQueryParam());
    }

    window.addEventListener('popstate', syncValue);
    return () => window.removeEventListener('popstate', syncValue);
  }, []);

  return [value, setParamValue];
}

export default useHistoryParam;
