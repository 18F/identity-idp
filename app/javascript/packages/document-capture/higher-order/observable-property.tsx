/**
 * Defines a property on the given object, calling the change callback when that property is set to
 * a new value.
 *
 * @param object Object on which to define property.
 * @param property Property name to observe.
 * @param onChangeCallback Callback to trigger on change.
 */
export function defineObservableProperty(
  object: any,
  property: string,
  onChangeCallback: (nextValue: any) => void,
) {
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
}

/**
 * Removes an observable property by removing the defined getter/setter methods
 * and replaces the value with the most recent value.
 *
 * @param object Object on which to remove defined property.
 * @param property Property name to remove observer for
 */
export function stopObservingProperty(object: any, property: string) {
  const currentValue = object[property];

  Object.defineProperty(object, property, { value: currentValue, writable: true });
}
