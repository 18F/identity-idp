import { useRef, useEffect, useCallback } from 'react';

/**
 * React hook which returns a callback function which itself maintains a constant reference, but
 * which invokes the latest reference of the given function.
 *
 * @see https://reactjs.org/docs/hooks-faq.html#how-to-read-an-often-changing-value-from-usecallback
 *
 * @param fn
 * @param dependencies Callback dependencies
 */
function useImmutableCallback<F extends (...args: any[]) => any>(fn: F, dependencies: any[] = []) {
  const ref = useRef((() => {}) as F);

  useEffect(() => {
    ref.current = fn;
  }, [fn, ...dependencies]);

  return useCallback(((...args) => ref.current(...args)) as F, [ref]);
}

export default useImmutableCallback;
