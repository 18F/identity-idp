import { useState, useEffect } from 'react';
import type { MutableRefObject } from 'react';
import { createFocusTrap } from 'focus-trap';
import type { FocusTrap, Options } from 'focus-trap';

/**
 * React hook which activates a focus trap on the given container ref while the component is
 * mounted, with any options for the underlying focus trap instance. The hook does not detect
 * changes to the options argument, thus new option values are not reflected and conversely
 * memoization is not necessary. Returns ref with trap instance assigned as current after mount.
 */
function useFocusTrap(containerRef: MutableRefObject<HTMLElement | null>, options?: Options) {
  const [trap, setTrap] = useState(null as FocusTrap | null);

  useEffect(() => {
    let focusTrap;
    if (containerRef.current) {
      focusTrap = createFocusTrap(containerRef.current, options);
      focusTrap.activate();
      setTrap(focusTrap);
    }

    return () => {
      focusTrap?.deactivate();
    };
  }, []);

  return trap;
}

export default useFocusTrap;
