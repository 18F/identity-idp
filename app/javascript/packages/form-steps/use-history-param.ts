import { useState, useEffect } from 'react';

interface HistoryOptions {
  basePath?: string;
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
 * @return Tuple of current state, state setter.
 */
function useHistoryParam({ basePath }: HistoryOptions = {}): [
  string | undefined,
  (nextParamValue?: string) => void,
] {
  const getCurrentQueryParam = () =>
    (typeof basePath === 'string'
      ? window.location.pathname.split(basePath)[1]?.replace(/\/$/, '')
      : window.location.hash.slice(1)) || undefined;

  const [value, setValue] = useState(getCurrentQueryParam);

  function getValueURL(nextValue) {
    const prefix = typeof basePath === 'string' ? basePath : '#';
    return nextValue ? `${prefix}${nextValue}` : window.location.pathname + window.location.search;
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
    const syncValue = () => setValue(getCurrentQueryParam());
    window.addEventListener('popstate', syncValue);
    return () => window.removeEventListener('popstate', syncValue);
  }, []);

  return [value, setParamValue];
}

export default useHistoryParam;
