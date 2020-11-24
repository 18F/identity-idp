import { useContext } from 'react';
import UploadContext from '../context/upload';
import AnalyticsContext from '../context/analytics';

/**
 * Returns a promise resolving to an DataView representation of the given Blob object.
 *
 * @param {Blob} blob Blob object.
 *
 * @return {Promise<DataView>}
 */
export function blobToDataView(blob) {
  return new Promise((resolve, reject) => {
    const reader = new window.FileReader();
    reader.onload = ({ target }) => {
      resolve(new DataView(/** @type {ArrayBuffer} */ (target?.result)));
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
    typeof value === 'string' ? new TextEncoder().encode(value) : await blobToDataView(value);

  return window.crypto.subtle.encrypt(
    /** @type {AesGcmParams} */ ({
      name: 'AES-GCM',
      iv,
    }),
    key,
    data,
  );
}

const withBackgroundEncryptedUpload = (Component) => ({ onChange, ...props }) => {
  const { backgroundUploadURLs, backgroundUploadEncryptKey } = useContext(UploadContext);
  const { addPageAction } = useContext(AnalyticsContext);

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
          .then((encryptedValue) =>
            window.fetch(url, {
              method: 'PUT',
              body: encryptedValue,
              headers: { 'Content-Type': 'application/octet-stream' },
            }),
          )
          .then((response) => {
            const traceId = response.headers.get('X-Amzn-Trace-Id');
            addPageAction('documentCapture.asyncUpload', {
              success: response.ok,
              trace_id: traceId,
            });

            if (!response.ok) {
              throw new Error('Failed to upload image');
            }

            return url;
          });
      }
    }

    onChange(nextValuesWithUpload);
  }

  // eslint-disable-next-line react/jsx-props-no-spreading
  return <Component {...props} onChange={onChangeWithBackgroundEncryptedUpload} />;
};

export default withBackgroundEncryptedUpload;
