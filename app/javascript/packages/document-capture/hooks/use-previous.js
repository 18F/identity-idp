import { useEffect, useRef } from 'react';

/**
 * Returns the value from the previous render's same hook call argument.
 *
 * @template T
 *
 * @param {T} value Value to recall later.
 *
 * @return {T=} Previous value, or undefined on first render.
 */
function usePrevious(value) {
  const ref = useRef(/** @type {T=} */ (undefined));

  useEffect(() => {
    ref.current = value;
  }, [value]);

  return ref.current;
}

export default usePrevious;
