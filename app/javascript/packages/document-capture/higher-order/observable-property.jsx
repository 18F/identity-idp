/**
 * Defines a property on the given object, calling the change callback when that property is set to
 * a new value.
 *
 * @param {any} object Object on which to define property.
 * @param {string} property Property name to observe.
 * @param {(nextValue: any) => void} onChangeCallback Callback to trigger on change.
 */
export function defineObservableProperty(object, property, onChangeCallback) {
  let currentValue;

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
}

/**
 * Removes an observable property by removing the defined getter/setter methods
 * and replaces the value with the most recent value.
 *
 * @param {any} object Object on which to remove defined property.
 * @param {string} property Property name to remove observer for
 */
export function stopObservingProperty(object, property) {
  const currentValue = object[property];

  Object.defineProperty(object, property, { value: currentValue, writable: true });
}
