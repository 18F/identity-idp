export interface FormErrorOptions {
  /**
   * Whether error message is to be presented in a context which accommodates a detailed
   * text description.
   */
  isDetail?: boolean;

  /**
   * Field with which the error is associated.
   */
  field?: string;
}

class FormError extends Error {
  field?: string;

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
    this.field = options?.field;
  }
}

export default FormError;
