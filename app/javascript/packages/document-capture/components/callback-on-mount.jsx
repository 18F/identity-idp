import { useEffect } from 'react';

/**
 * @typedef CallbackOnMountProps
 *
 * @prop {()=>void} onMount Callback to trigger on mount.
 */

/**
 * @param {CallbackOnMountProps} props Props object.
 */
function CallbackOnMount({ onMount }) {
  useEffect(() => {
    onMount();
  }, []);

  return null;
}

export default CallbackOnMount;
