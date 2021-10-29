import { useEffect } from 'react';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef CallbackOnMountProps
 *
 * @prop {()=>void} onMount Callback to trigger on mount.
 * @prop {JSX.Element?=} children Element children.
 */

/**
 * @param {CallbackOnMountProps} props Props object.
 *
 * @return {JSX.Element?}
 */
function CallbackOnMount({ onMount, children = null }) {
  useEffect(() => {
    onMount();
  }, []);

  return children;
}

export default CallbackOnMount;
