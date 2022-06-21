import { FormError } from '@18f/identity-form-steps';
import type {
  UploadSuccessResponse,
  UploadErrorResponse,
  UploadFieldError,
  UploadImplementation,
} from '../context/upload';

export class UploadFormEntryError extends FormError {
  field = '';
}

export class UploadFormEntriesError extends FormError {
  formEntryErrors: UploadFormEntryError[] = [];

  remainingAttempts = Infinity;

  hints = false;
}

/**
 * Returns a FormData representation of the given object.
 */
export function toFormData(object: Record<string, any>): FormData {
  return Object.keys(object).reduce((form, key) => {
    const value = object[key];
    if (value !== undefined) {
      form.append(key, value);
    }

    return form;
  }, new window.FormData());
}

/**
 * Returns error as received by server as an instance of UploadFormEntryError.
 */
export function toFormEntryError(uploadFieldError: UploadFieldError): UploadFormEntryError {
  const { field, message } = uploadFieldError;
  const formEntryError = new UploadFormEntryError(message);
  formEntryError.field = field;
  return formEntryError;
}

const upload: UploadImplementation = async function (payload, { method = 'POST', endpoint, csrf }) {
  const headers: HeadersInit = {};
  if (csrf) {
    headers['X-CSRF-Token'] = csrf;
  }
  const response = await window.fetch(endpoint, { method, headers, body: toFormData(payload) });

  if (!response.ok && !response.status.toString().startsWith('4')) {
    // 4xx is an expected error state, handled after JSON deserialization. Anything else not OK
    // should be treated as an unhandled error.
    throw new Error(response.statusText);
  }

  if (response.url !== endpoint) {
    window.onbeforeunload = null;
    window.location.href = response.url;

    // Avoid settling the promise, allowing the redirect to complete.
    return new Promise(() => {});
  }

  const result: UploadSuccessResponse | UploadErrorResponse = await response.json();
  if (!result.success) {
    if (result.redirect) {
      window.onbeforeunload = null;
      window.location.href = result.redirect;

      // Avoid settling the promise, allowing the redirect to complete.
      return new Promise(() => {});
    }

    const error = new UploadFormEntriesError();
    if (result.errors) {
      error.formEntryErrors = result.errors.map(toFormEntryError);
    }

    if (result.remaining_attempts) {
      error.remainingAttempts = result.remaining_attempts;
    }

    if (result.hints) {
      error.hints = result.hints;
    }

    throw error;
  }

  result.isPending = response.status === 202;

  return result;
};

export default upload;
