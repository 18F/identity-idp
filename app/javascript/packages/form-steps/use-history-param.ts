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
 * @param queryString Query string to search within.
 * @param name        Parameter name to search for.
 *
 * @return Decoded parameter value if found, or null otherwise.
 */
export function getQueryParam(queryString: string, name: string): string | null {
  const pairs = queryString.split('&');
  for (let i = 0; i < pairs.length; i += 1) {
    const [key, value = ''] = pairs[i].split('=').map(decodeURIComponent);
    if (key === name) {
      return value;
    }
  }

  return null;
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
 * @param name Parameter name to sync.
 * @param initialValue Value to use as initial in absence of another value.
 *
 * @return Tuple of current state, state setter.
 */
function useHistoryParam(
  name: string,
  initialValue?: string | null,
): [any, (nextParamValue: any) => void] {
  const getCurrentQueryParam = () =>
    getQueryParam(window.location.hash.slice(1), name) ?? undefined;

  const [value, setValue] = useState(getCurrentQueryParam);

  function getValueURL(nextValue) {
    return nextValue
      ? `#${[name, nextValue].map(encodeURIComponent).join('=')}`
      : window.location.pathname + window.location.search;
  }

  function setParamValue(nextValue) {
    // Push the next value to history, both to update the URL, and to allow the user to return to
    // an earlier value (see `popstate` sync behavior).
    if (nextValue !== value) {
      window.history.pushState(null, '', getValueURL(nextValue));
      setValue(nextValue);
    }

    if (window.scrollY > 0) {
      window.scrollTo(0, 0);
    }
  }

  useEffect(() => {
    function syncValue() {
      setValue(getCurrentQueryParam());
    }

    if (initialValue !== undefined) {
      setValue(initialValue ?? undefined);
      window.history.replaceState(null, '', getValueURL(initialValue));
    }

    window.addEventListener('popstate', syncValue);
    return () => window.removeEventListener('popstate', syncValue);
  }, []);

  return [value, setParamValue];
}

export default useHistoryParam;
