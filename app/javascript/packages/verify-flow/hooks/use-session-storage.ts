import { useState } from 'react';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import type { Dispatch } from 'react';

/**
 * React hook for maintaining a value in sessionStorage.
 *
 * @param key Session storage key.
 *
 * @return Tuple of the current value and a setter to assign a value into storage.
 */
function useSessionStorage(key: string): [string | null, Dispatch<string | null>] {
  const [value, setValue] = useState(() => sessionStorage.getItem(key));
  useDidUpdateEffect(() => {
    if (value === null) {
      sessionStorage.removeItem(key);
    } else {
      sessionStorage.setItem(key, value);
    }
  }, [value]);

  return [value, setValue];
}

export default useSessionStorage;
