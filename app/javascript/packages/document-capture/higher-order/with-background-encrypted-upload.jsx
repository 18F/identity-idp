import { useContext } from 'react';
import { t } from '@18f/identity-i18n';
import { FormError } from '@18f/identity-form-steps';
import UploadContext from '../context/upload';
import AnalyticsContext from '../context/analytics';

/**
 * @typedef {import('@18f/identity-form-steps').FormStepComponentProps<V>} FormStepComponentProps
 * @template V
 */

/**
 * Non-breaking space (`&nbsp;`) represented as unicode escape sequence, which React will more
 * happily tolerate than an HTML entity.
 */
const NBSP_UNICODE = '\u00A0';

/**
 * Returns a new string from the given string, replacing spaces with non-breaking spaces.
 *
 * @param {string} string Original string.
 *
 * @return String with non-breaking spaces.
 */
const nonBreaking = (string) => string.split(' ').join(NBSP_UNICODE);

/**
 * An error representing a failure to complete encrypted upload of image.
 */
export class BackgroundEncryptedUploadError extends FormError {
  baseField = '';

  /** @type {string[]} */
  fields = [];

  message = `${t('doc_auth.errors.upload_error')} ${nonBreaking(t('errors.messages.try_again'))}`;
}

/**
 * Returns a promise resolving to an ArrayBuffer representation of the given Blob object.
 *
 * @param {Blob} blob Blob object.
 *
 * @return {Promise<ArrayBuffer>}
 */
export function blobToArrayBuffer(blob) {
  return new Promise((resolve, reject) => {
    const reader = new window.FileReader();
    reader.onload = ({ target }) => {
      resolve(/** @type {ArrayBuffer} */ (target?.result));
    };
    reader.onerror = () => reject(reader.error);
    reader.readAsArrayBuffer(blob);
  });
}

/**
 * Encrypt data.
 *
 * @param {CryptoKey} key Encryption key.
 * @param {BufferSource} iv Initialization vector.
 * @param {string|Blob} value Value to encrypt.
 *
 * @return {Promise<ArrayBuffer>} Encrypted data.
 */
export async function encrypt(key, iv, value) {
  const data =
    typeof value === 'string' ? new TextEncoder().encode(value) : await blobToArrayBuffer(value);

  return window.crypto.subtle.encrypt(
    /** @type {AesGcmParams} */ ({
      name: 'AES-GCM',
      iv,
    }),
    key,
    data,
  );
}

const withBackgroundEncryptedUpload = (Component) => {
  /**
   * @param {Pick<FormStepComponentProps<Record<string,any>>, 'onChange'|'onError'>} props
   */
  function ComposedComponent({ onChange, onError, ...props }) {
    const { backgroundUploadURLs, backgroundUploadEncryptKey } = useContext(UploadContext);
    const { addPageAction, noticeError } = useContext(AnalyticsContext);

    /**
     * @param {Record<string, string|Blob|null|undefined>} nextValues Next values.
     */
    function onChangeWithBackgroundEncryptedUpload(nextValues) {
      const nextValuesWithUpload = {};
      for (const [key, value] of Object.entries(nextValues)) {
        nextValuesWithUpload[key] = value;
        const url = backgroundUploadURLs[key];
        if (url && value) {
          const iv = window.crypto.getRandomValues(new Uint8Array(12));
          nextValuesWithUpload[`${key}_image_iv`] = window.btoa(String.fromCharCode(...iv));
          nextValuesWithUpload[`${key}_image_url`] = encrypt(
            /** @type {CryptoKey} */ (backgroundUploadEncryptKey),
            iv,
            value,
          )
            .catch((error) => {
              addPageAction({
                label: 'IdV: document capture async upload encryption',
                payload: {
                  success: false,
                },
              });
              noticeError(error);

              // Rethrow error to skip upload and proceed from next `catch` block.
              throw error;
            })
            .then((encryptedValue) => {
              addPageAction({
                label: 'IdV: document capture async upload encryption',
                payload: {
                  success: true,
                },
              });

              return window.fetch(url, {
                method: 'PUT',
                body: encryptedValue,
                headers: { 'Content-Type': 'application/octet-stream' },
              });
            })
            .then((response) => {
              const traceId = response.headers.get('X-Amzn-Trace-Id');
              addPageAction({
                key: 'documentCapture.asyncUpload',
                label: 'IdV: document capture async upload submitted',
                payload: {
                  success: response.ok,
                  trace_id: traceId,
                  status_code: response.status,
                },
              });

              if (!response.ok) {
                throw new Error();
              }

              return url;
            })
            .catch(() => {
              onChange({ [key]: null });
              const error = new BackgroundEncryptedUploadError();
              error.baseField = key;
              error.fields = [key, `${key}_image_iv`, `${key}_image_url`];
              onError(error, { field: key });
              throw error;
            });
        }
      }

      onChange(nextValuesWithUpload);
    }

    return (
      <Component {...props} onError={onError} onChange={onChangeWithBackgroundEncryptedUpload} />
    );
  }

  ComposedComponent.displayName = `WithBackgroundEncryptedUpload(${
    Component.displayName || Component.name
  })`;

  return ComposedComponent;
};

export default withBackgroundEncryptedUpload;
