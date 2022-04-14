import { useRef, useEffect } from 'react';

/**
 * Hook which returns a higher-order function to compose another function to be
 * executed only if the component is mounted.
 *
 * Note that this can be useful in creating safe callbacks for promise results,
 * but since dangling references to components can cause memory leaks, it's
 * preferred to cancel a subscription immediately on unmount whenever possible.
 *
 * @see https://reactjs.org/blog/2015/12/16/ismounted-antipattern.html
 */
function useIfStillMounted() {
  const isMounted = useRef(false);
  useEffect(() => {
    isMounted.current = true;
    return () => {
      isMounted.current = false;
    };
  });

  const ifStillMounted = <T extends (...args) => any>(fn: T) =>
    ((...args) => {
      if (isMounted.current) {
        fn(...args);
      }
    }) as T;

  return ifStillMounted;
}

export default useIfStillMounted;
