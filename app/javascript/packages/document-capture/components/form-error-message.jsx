import { UploadFormEntryError } from '../services/upload';
import { BackgroundEncryptedUploadError } from '../higher-order/with-background-encrypted-upload';
import useI18n from '../hooks/use-i18n';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef FormErrorMessageProps
 *
 * @prop {Error} error Error for which message should be generated.
 */

/**
 * An error representing a state where a required form value is missing.
 */
export class RequiredValueMissingError extends Error {}

/**
 * @param {FormErrorMessageProps} props Props object.
 */
function FormErrorMessage({ error }) {
  const { t } = useI18n();

  if (error instanceof RequiredValueMissingError) {
    return <>{t('simple_form.required.text')}</>;
  }

  if (error instanceof UploadFormEntryError) {
    return <>{error.message}</>;
  }

  if (error instanceof BackgroundEncryptedUploadError) {
    return <>{t('errors.doc_auth.upload_error')}</>;
  }

  return null;
}

export default FormErrorMessage;
