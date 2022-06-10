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
  formEntryErrors = [] as UploadFormEntryError[];

  remainingAttempts = Infinity ;

  hints = false;
}

/**
 * Returns a FormData representation of the given object.
 *
 * @param {Record<string,any>} object Object to serialize.
 *
 * @return {FormData}
 */
export function toFormData(object) {
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
 *
 * @param {UploadFieldError} uploadFieldError Error received from server.
 *
 * @return {UploadFormEntryError}
 */
export function toFormEntryError(uploadFieldError: UploadFieldError) {
  const { field, message } = uploadFieldError;
  const formEntryError = new UploadFormEntryError(message);
  formEntryError.field = field;
  return formEntryError;
}

async function upload(payload, { method = 'POST', endpoint, csrf }) {
  /** @type {HeadersInit} */
  const headers = {};
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

  const result = (await response.json()) as UploadSuccessResponse | UploadErrorResponse;
  if (!result.success) {
    const errorResult = result as UploadErrorResponse;

    if (errorResult.redirect) {
      window.onbeforeunload = null;
      window.location.href = errorResult.redirect;

      // Avoid settling the promise, allowing the redirect to complete.
      return new Promise(() => {});
    }

    const error = new UploadFormEntriesError();
    if (errorResult.errors) {
      error.formEntryErrors = errorResult.errors.map(toFormEntryError);
    }

    if (errorResult.remaining_attempts) {
      error.remainingAttempts = errorResult.remaining_attempts;
    }

    if (errorResult.hints) {
      error.hints = errorResult.hints;
    }

    throw error;
  }

  result.isPending = response.status === 202;

  return result as UploadSuccessResponse;
}

export default upload as UploadImplementation;
