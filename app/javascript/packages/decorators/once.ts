export const once =
  (): MethodDecorator =>
  <T>(_target, propertyKey, descriptor) => {
    const { value, get } = descriptor;
    if (typeof value === 'function') {
      descriptor.value = function () {
        const result = value.call(this) as T;
        Object.defineProperty(this, propertyKey, { value: () => result });
        return result;
      };
    } else if (get) {
      descriptor.get = function () {
        const result = get.call(this) as T;
        Object.defineProperty(this, propertyKey, { value: result });
        return result;
      };
    }

    return descriptor;
  };
