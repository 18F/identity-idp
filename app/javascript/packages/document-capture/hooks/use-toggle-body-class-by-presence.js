import { useEffect } from 'react';

/**
 * @type {WeakMap<*, number>}
 */
const activeInstancesByType = new WeakMap();

/**
 * React hook to add a CSS class to the page body element as long as any instance of the given
 * component type is rendered to the page.
 *
 * @param {string} className Class name to add to body element
 * @param {React.ComponentType<any>} Component React component definition
 */
function useToggleBodyClassByPresence(className, Component) {
  /**
   * Increments the number of active instances for the current component by the given amount, adding
   * or removing the body class for the first and last instance respectively.
   *
   * @param {number} amount
   */
  function incrementActiveInstances(amount) {
    const activeInstances = activeInstancesByType.get(Component) || 0;
    const nextActiveInstances = activeInstances + amount;

    if (!activeInstances && nextActiveInstances) {
      document.body.classList.add(className);
    } else if (activeInstances && !nextActiveInstances) {
      document.body.classList.remove(className);
    }

    activeInstancesByType.set(Component, nextActiveInstances);
  }

  useEffect(() => {
    incrementActiveInstances(1);
    return () => incrementActiveInstances(-1);
  }, []);
}

export default useToggleBodyClassByPresence;
