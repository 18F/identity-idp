import { FormError } from '@18f/identity-form-steps';
import { forceRedirect } from '@18f/identity-url';
import { request } from '@18f/identity-request';
import type {
  UploadSuccessResponse,
  UploadErrorResponse,
  UploadFieldError,
  UploadImplementation,
  ImageFingerprints,
} from '../context/upload';

/**
 * Personally-identifiable information extracted from document subject to user confirmation.
 */
export interface PII {
  /**
   * First name from document.
   */
  first_name: string;

  /**
   * Last name from document.
   */
  last_name: string;

  /**
   * Date of birth from document.
   */
  dob: string;
}

export class UploadFormEntryError extends FormError {
  field = '';
}

export class UploadFormEntriesError extends FormError {
  formEntryErrors: UploadFormEntryError[] = [];

  remainingSubmitAttempts = Infinity;

  isResultCodeInvalid = false;

  isFailedResult = false;

  isFailedDocType = false;

  isFailedSelfie = false;

  selfieNotLive = false;

  selfieNotGoodQuality = false;

  pii?: PII;

  hints = false;

  failed_image_fingerprints: ImageFingerprints = { front: [], back: [] };
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

const upload: UploadImplementation = async function (payload, { method = 'POST', endpoint }) {
  const response = await request(endpoint, {
    method,
    body: toFormData(payload),
    json: false,
    read: false,
  });

  if (!response.ok && !response.status.toString().startsWith('4')) {
    // 4xx is an expected error state, handled after JSON deserialization. Anything else not OK
    // should be treated as an unhandled error.
    throw new Error(response.statusText);
  }

  if (response.url !== endpoint) {
    forceRedirect(response.url);

    // Avoid settling the promise, allowing the redirect to complete.
    return new Promise(() => {});
  }

  const result: UploadSuccessResponse | UploadErrorResponse = await response.json();
  if (!result.success) {
    if (result.redirect) {
      forceRedirect(result.redirect);

      // Avoid settling the promise, allowing the redirect to complete.
      return new Promise(() => {});
    }

    const error = new UploadFormEntriesError();
    if (result.errors) {
      error.formEntryErrors = result.errors.map(toFormEntryError);
    }

    if (result.remaining_submit_attempts) {
      error.remainingSubmitAttempts = result.remaining_submit_attempts;
    }

    if (result.ocr_pii) {
      error.pii = result.ocr_pii;
    }

    if (result.hints) {
      error.hints = result.hints;
    }

    error.isResultCodeInvalid = result.result_code_invalid;

    error.isFailedResult = !!result.result_failed;

    error.isFailedSelfie = result.selfie_status === 'fail';

    error.isFailedDocType = !result.doc_type_supported;

    error.selfieNotLive = result.selfie_live === undefined ? false : !result.selfie_live;

    error.selfieNotGoodQuality =
      result.selfie_quality_good === undefined ? false : !result.selfie_quality_good;

    error.failed_image_fingerprints = result.failed_image_fingerprints ?? { front: [], back: [] };

    throw error;
  }

  result.isPending = response.status === 202;

  return result;
};

export default upload;
