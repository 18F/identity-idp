import { useRef } from 'react';

/**
 * Returns a ref callback to be assigned to a React element. Calls focus on the given fallbackRef
 * argument if focus was on the assigned element at the time it's unmounted.
 *
 * @param {import('react').RefObject<HTMLElement>} fallbackRef Fallback ref to focus if element is
 * active element at the time it is unmounted.
 *
 * @return {import('react').RefCallback<HTMLElement>}
 */
function useFocusFallbackRef(fallbackRef) {
  const ref = useRef(/** @type {HTMLElement?} */ (null));

  return (nextRef) => {
    if (!nextRef && ref.current === document.activeElement) {
      fallbackRef.current?.focus();
    }

    ref.current = nextRef;
  };
}

export default useFocusFallbackRef;
