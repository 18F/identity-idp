import { useEffect } from 'react';

/**
 * Defines a property on the given object as an effect,
 * It will call the change callback when that property is set to
 * a new value.
 *
 * No-ops if object is not present.
 *
 * @param object Object on which to define property.
 * @param property Property name to observe.
 * @param onChangeCallback Callback to trigger on change.
 */
export function useObservableProperty(object: any, property: string, onChangeCallback: (nextValue: any) => void) {
  useEffect(() => {
    if (!object) {
      return;
    }

    let currentValue: any;

    Object.defineProperty(object, property, {
      get() {
        return currentValue;
      },
      set(nextValue) {
        currentValue = nextValue;
        onChangeCallback(nextValue);
      },
      configurable: true,
    });

    return () => {
      const value = object[property];

      Object.defineProperty(object, property, { value, writable: true });
    };
  }, [object, property, onChangeCallback]);
}
