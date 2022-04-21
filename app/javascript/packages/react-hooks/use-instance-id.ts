import { useMemo } from 'react';

let instances = 0;

/**
 * Returns a string value guaranteed to be unique to all element instances in the application. This
 * can be used in generic unique IDs when needed in, for example, form input label association.
 */
function useInstanceId() {
  return useMemo(() => {
    instances += 1;
    return String(instances);
  }, []);
}

export default useInstanceId;
