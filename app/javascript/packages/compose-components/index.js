import { createElement } from 'react';

/** @typedef {import('react').ComponentType<P>} ComponentType @template P */

/**
 * @typedef {[ComponentType<P>, P]} NormalizedComponentPair
 *
 * @template P
 */

/**
 * @typedef {[ComponentType<P>, P]|[ComponentType<P>]|ComponentType<P>} ComponentPair
 *
 * @template P
 */

/**
 * A utility function to compose a set of React components and their props to a single component.
 *
 * Convenient for flattening a deeply-nested arrangement of context providers, for example.
 *
 * @example
 * ```jsx
 * const App = composeComponents(
 *   [FirstContext.Provider, { value: 1 }],
 *   [SecondContext.Provider, { value: 2 }],
 *   AppRoot,
 * );
 *
 * render(App, document.getElementById('app-root'));
 * ```
 *
 * @param {...ComponentPair<*>} components
 *
 * @return {ComponentType<*>}
 */
export function composeComponents(...components) {
  return function ComposedComponent() {
    /** @type {JSX.Element?} */
    let element = null;
    for (let i = components.length - 1; i >= 0; i--) {
      const componentPair = /** @type {NormalizedComponentPair<*>} */ (Array.isArray(components[i])
        ? components[i]
        : [components[i]]);
      const [ComponentType, props] = componentPair;
      element = createElement(ComponentType, props, element);
    }

    return element;
  };
}
