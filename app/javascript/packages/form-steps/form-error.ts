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
}

class FormError extends Error {
  field?: string;

  isDetail: boolean;

  messageProcessor?: (message: string) => string | ReactNode;

  constructor(
    message?: string,
    options?: FormErrorOptions,
    messageProcessor?: (message: string) => string | ReactNode,
  ) {
    super(message);

    this.isDetail = Boolean(options?.isDetail);
    this.field = options?.field;
    this.messageProcessor = messageProcessor;
  }
}

export default FormError;
