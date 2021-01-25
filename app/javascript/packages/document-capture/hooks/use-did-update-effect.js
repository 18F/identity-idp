import { useRef, useEffect } from 'react';

/**
 * @type {typeof useEffect}
 */
function useDidUpdateEffect(callback, deps) {
  const isMounting = useRef(true);

  useEffect(() => {
    if (isMounting.current) {
      isMounting.current = false;
    } else {
      callback();
    }
  }, deps);
}

export default useDidUpdateEffect;
