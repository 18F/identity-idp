import { useRef, useEffect, useCallback } from 'react';

/**
 * React hook which returns a callback function which itself maintains a constant reference, but
 * which invokes the latest reference of the given function.
 *
 * @see https://reactjs.org/docs/hooks-faq.html#how-to-read-an-often-changing-value-from-usecallback
 *
 * @template {(...args: any[]) => any} F
 *
 * @param {F} fn
 * @param {any[]=} dependencies Callback dependencies
 *
 * @return {F}
 */
function useImmutableCallback(fn, dependencies = []) {
  const ref = useRef(/** @type {F} */ (() => {}));

  useEffect(() => {
    ref.current = fn;
  }, [fn, ...dependencies]);

  return useCallback(/** @type {F} */ ((...args) => ref.current(...args)), [ref]);
}

export default useImmutableCallback;
