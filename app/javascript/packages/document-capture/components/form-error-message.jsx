import { useI18n } from '@18f/identity-react-i18n';
import { UploadFormEntryError } from '../services/upload';
import { BackgroundEncryptedUploadError } from '../higher-order/with-background-encrypted-upload';

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef FormErrorMessageProps
 *
 * @prop {Error} error Error for which message should be generated.
 * @prop {boolean=} isDetail Whether to use an extended description for the error, if available.
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
 * An error representing user declined access to camera.
 */
export class CameraAccessDeclinedError extends Error {}

/**
 * @param {FormErrorMessageProps} props Props object.
 */
function FormErrorMessage({ error, isDetail = false }) {
  const { t } = useI18n();

  if (error instanceof RequiredValueMissingError) {
    return <>{t('simple_form.required.text')}</>;
  }

  if (error instanceof CameraAccessDeclinedError) {
    return (
      <>
        {isDetail
          ? t('doc_auth.errors.camera.blocked_detail')
          : t('doc_auth.errors.camera.blocked')}
      </>
    );
  }

  if (error instanceof UploadFormEntryError) {
    return <>{error.message}</>;
  }

  if (error instanceof BackgroundEncryptedUploadError) {
    return (
      <>
        {t('doc_auth.errors.upload_error')}{' '}
        {t('errors.messages.try_again').split(' ').join(NBSP_UNICODE)}
      </>
    );
  }

  return null;
}

export default FormErrorMessage;
