import { useMemo } from 'react';

/**
 * React hook which creates a memoized object whose reference changes when values of the object
 * changes.
 *
 * This can be useful in situations like object context values, since without memoization an object
 * context would trigger re-renders of all consumers on every update.
 *
 * Note that the keys of the object (and their order) must remain the same for the lifecycle of the
 * component for the hook to work correctly.
 *
 * @param object Object to memoize.
 *
 * @return Memoized object.
 */
const useObjectMemo = <T extends object>(object: T): T =>
  useMemo(() => object, Object.values(object));

export default useObjectMemo;
