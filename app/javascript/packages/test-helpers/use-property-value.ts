/**
 * Temporarily override a property value for the duration of a test, restoring the original value
 * after the current test scope.
 *
 * @param object Object on which to override property.
 * @param property Property key.
 * @param value Temporary property value.
 */
function usePropertyValue<O extends object>(object: O, property: keyof O, value: any) {
  let originalValue;
  before(() => {
    originalValue = object[property];
    object[property] = value;
  });

  after(() => {
    object[property] = originalValue;
  });
}

export default usePropertyValue;
