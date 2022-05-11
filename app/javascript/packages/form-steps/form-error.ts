export interface FormErrorOptions {
  /**
   * Whether error message is to be presented in a context which accommodates a detailed
   * text description.
   */
  isDetail?: boolean;

  /**
   * Field associated with the erorr.
   */
  field?: string;
}

class FormError extends Error {
  field?: string;

  isDetail: boolean;

  constructor(message?: string, options?: FormErrorOptions) {
    super();

    if (message) {
      this.message = message;
    }

    this.isDetail = Boolean(options?.isDetail);
    this.field = options?.field;
  }
}

export default FormError;
