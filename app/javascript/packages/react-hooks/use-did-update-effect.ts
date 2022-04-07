import { useRef, useEffect } from 'react';

/**
 * A hook behaving the same as useEffect in invoking the given callback when dependencies change,
 * but does not call the callback during initial mount or when unmounting. It can be considered as
 * similar to ReactComponent#componentDidUpdate.
 */
const useDidUpdateEffect: typeof useEffect = (callback, deps) => {
  const isMounting = useRef(true);

  useEffect(() => {
    if (isMounting.current) {
      isMounting.current = false;
    } else {
      callback();
    }
  }, deps);
};

export default useDidUpdateEffect;
