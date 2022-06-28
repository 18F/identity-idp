import { useState, useEffect, useCallback } from 'react';

export type ParamValue = string | undefined;

interface HistoryOptions {
  basePath?: string;
}

/**
 * Returns the step name from a given path, ignoring any subpaths or leading or trailing slashes.
 *
 * @param path Path from which to extract step.
 *
 * @return Step name.
 */
export const getStepParam = (path: string): string =>
  decodeURIComponent(path.split('/').filter(Boolean)[0]);

export function getParamURL(value: ParamValue, { basePath }: HistoryOptions): string {
  let prefix = typeof basePath === 'string' ? basePath.replace(/\/$/, '') : '#';
  if (value && basePath) {
    prefix += '/';
  }

  return [prefix, encodeURIComponent(value || '')].filter(Boolean).join('');
}

const onURLChange = () => window.dispatchEvent(new window.CustomEvent('lg:url-change'));

const subscribers: Array<() => void> = [];

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
function useHistoryParam(
  initialValue?: string,
  { basePath }: HistoryOptions = {},
): [string | undefined, (nextParamValue: ParamValue) => void] {
  function getCurrentValue(): ParamValue {
    const path =
      typeof basePath === 'string'
        ? window.location.pathname.split(basePath)[1]
        : window.location.hash.slice(1);

    if (path) {
      return getStepParam(path);
    }
  }

  const [value, setValue] = useState(initialValue ?? getCurrentValue);
  const syncValue = useCallback(() => setValue(getCurrentValue), [setValue]);

  function setParamValue(nextValue: ParamValue) {
    // Push the next value to history, both to update the URL, and to allow the user to return to
    // an earlier value (see `popstate` sync behavior).
    if (nextValue !== value) {
      window.history.pushState(null, '', getParamURL(nextValue, { basePath }));
      onURLChange();
      subscribers.forEach((sync) => sync());
    }

    if (window.scrollY > 0) {
      window.scrollTo(0, 0);
    }
  }

  useEffect(() => {
    if (initialValue && initialValue !== getCurrentValue()) {
      window.history.replaceState(null, '', getParamURL(initialValue, { basePath }));
      onURLChange();
    }

    window.addEventListener('popstate', syncValue);
    window.addEventListener('popstate', onURLChange);
    return () => {
      window.removeEventListener('popstate', syncValue);
      window.removeEventListener('popstate', onURLChange);
    };
  }, []);

  useEffect(() => {
    subscribers.push(syncValue);
    return () => {
      subscribers.splice(subscribers.indexOf(syncValue), 1);
    };
  }, []);

  return [value, setParamValue];
}

export default useHistoryParam;
