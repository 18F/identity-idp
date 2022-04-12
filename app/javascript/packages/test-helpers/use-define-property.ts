type RedefinedProperty = [any, PropertyKey, PropertyDescriptor | undefined];

/**
 * A proxy to Object.defineProperty to use in redefining an existing object and reverting that
 * definition to its original value after the test has completed.
 */
function useDefineProperty(): ObjectConstructor['defineProperty'] {
  let redefined: Array<RedefinedProperty> = [];

  afterEach(() => {
    redefined.forEach(([object, property, originalDescriptor]) => {
      delete object[property];
      if (originalDescriptor !== undefined) {
        Object.defineProperty(object, property, originalDescriptor);
      }
    });

    redefined = [];
  });

  return function defineProperty<O>(
    object: O,
    property: PropertyKey,
    descriptor: PropertyDescriptor,
  ) {
    const originalDescriptor = Object.getOwnPropertyDescriptor(object, property);
    redefined.push([object, property, originalDescriptor]);
    return Object.defineProperty(object, property, descriptor);
  };
}

export default useDefineProperty;
