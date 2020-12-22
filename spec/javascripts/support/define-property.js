/**
 * A proxy to Object.defineProperty to use in redefining an existing object and reverting that
 * definition to its original value after the test has completed.
 *
 * @return {ObjectConstructor['defineProperty']}
 */
export default function useDefineProperty() {
  let redefined = [];

  afterEach(() => {
    redefined.forEach(([object, property, originalDescriptor]) => {
      delete object[property];
      if (originalDescriptor !== undefined) {
        Object.defineProperty(object, property, originalDescriptor);
      }
    });

    redefined = [];
  });

  return function defineProperty(object, property, descriptor) {
    const originalDescriptor = Object.getOwnPropertyDescriptor(object, property);
    redefined.push([object, property, originalDescriptor]);
    Object.defineProperty(object, property, descriptor);
  };
}
