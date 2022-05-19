import { useState, useEffect } from 'react';

type ParamValue = string | undefined;

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
export const getStepParam = (path: string): string => path.split('/').filter(Boolean)[0];

export function getParamURL(value, { basePath }: HistoryOptions): string {
  let prefix = typeof basePath === 'string' ? basePath.replace(/\/$/, '') : '#';
  if (value && basePath) {
    prefix += '/';
  }

  return [prefix, value].filter(Boolean).join('');
}

const subscribers: Array<(nextValue: ParamValue) => void> = [];

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

  function setParamValue(nextValue: ParamValue) {
    // Push the next value to history, both to update the URL, and to allow the user to return to
    // an earlier value (see `popstate` sync behavior).
    if (nextValue !== value) {
      window.history.pushState(null, '', getParamURL(nextValue, { basePath }));
      subscribers.forEach((subscriberSetValue) => subscriberSetValue(nextValue));
    }

    if (window.scrollY > 0) {
      window.scrollTo(0, 0);
    }
  }

  useEffect(() => {
    if (initialValue && initialValue !== getCurrentValue()) {
      window.history.replaceState(null, '', getParamURL(initialValue, { basePath }));
    }

    const syncValue = () => setValue(getCurrentValue());
    window.addEventListener('popstate', syncValue);
    return () => window.removeEventListener('popstate', syncValue);
  }, []);

  useEffect(() => {
    subscribers.push(setValue);
    return () => {
      subscribers.splice(subscribers.indexOf(setValue), 1);
    };
  }, [setValue]);

  return [value, setParamValue];
}

export default useHistoryParam;
