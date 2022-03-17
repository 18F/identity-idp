export const once = (): MethodDecorator => <T>(_target, _propertyKey, descriptor) => {
  const get = descriptor.get!;
  descriptor.get = function () {
    if (!descriptor.value) {
      descriptor.value = get.call(this) as T;
    }

    return descriptor.value;
  };

  return descriptor;
};
