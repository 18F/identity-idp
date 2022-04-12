export interface FormErrorOptions {
  /**
   * Whether error message is to be presented in a context which accommodates a detailed
   * text description.
   */
  isDetail?: boolean;
}

class FormError extends Error {
  isDetail?: boolean;

  constructor(messageOrOptions?: FormErrorOptions | string, options?: FormErrorOptions) {
    super();

    switch (typeof messageOrOptions) {
      case 'string':
        this.message = messageOrOptions;
        break;

      case 'object':
        options = messageOrOptions;
        break;

      default:
    }

    this.isDetail = Boolean(options?.isDetail);
  }
}

export default FormError;
