export interface FormErrorOptions {
  /**
   * Whether error message is to be presented in a context which accommodates a detailed
   * text description.
   */
  isDetail?: boolean;
}

class FormError extends Error {
  isDetail: boolean;

  constructor(options?: { isDetail: boolean }) {
    super();

    this.isDetail = Boolean(options?.isDetail);
  }
}

export default FormError;
