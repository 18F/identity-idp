import { ReactNode } from 'react';

export interface FormErrorOptions {
  /**
   * Whether error message is to be presented in a context which accommodates a detailed
   * text description.
   */
  isDetail?: boolean;

  /**
   * Field associated with the error.
   */
  field?: string;

  messageProcessor?: (message: string) => string | ReactNode;
}

class FormError extends Error {
  field?: string;

  isDetail: boolean;

  messageProcessor?: (message: string) => string | ReactNode;

  constructor(message?: string, options?: FormErrorOptions) {
    super(message);

    this.isDetail = Boolean(options?.isDetail);
    this.field = options?.field;
    this.messageProcessor = options?.messageProcessor;
  }
}

export default FormError;
