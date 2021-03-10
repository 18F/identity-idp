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
 * Non-breaking space (`&nbsp;`) represented as unicode escape sequence, which React will more
 * happily tolerate than an HTML entity.
 *
 * @type {string}
 */
const NBSP_UNICODE = '\u00A0';

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
    return (
      <>
        {t('errors.doc_auth.upload_error')}{' '}
        {t('errors.messages.try_again').split(' ').join(NBSP_UNICODE)}
      </>
    );
  }

  return null;
}

export default FormErrorMessage;
