import React, { createContext, useMemo } from 'react';
import defaultUpload from '../services/upload';

const UploadContext = createContext({
  upload: defaultUpload,
  getStatus: /** @type {() => Promise<UploadSuccessResponse>} */ (() => Promise.reject()),
  isMockClient: false,
  backgroundUploadURLs: /** @type {Record<string,string>} */ ({}),
  backgroundUploadEncryptKey: /** @type {CryptoKey=} */ (undefined),
});

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * Upload field error, after normalized to error instance.
 *
 * @typedef UploadFieldError
 *
 * @prop {'front'|'back'|'selfie'|'network'} field Field name.
 * @prop {string} message Error message.
 */

/**
 * @typedef UploadOptions
 *
 * @prop {'POST'|'PUT'} method HTTP method to send payload.
 * @prop {string} endpoint Endpoint to which payload should be sent.
 * @prop {string} csrf CSRF token to send as parameter to upload implementation.
 */

/**
 * @typedef UploadSuccessResponse
 *
 * @prop {true} success Whether request was successful.
 * @prop {boolean} isPending Whether verification result is still pending.
 */

/**
 * @typedef UploadErrorResponse
 *
 * @prop {false} success Whether request was successful.
 * @prop {UploadFieldError[]=} errors Error messages.
 * @prop {string=} redirect URL to which user should be redirected.
 */

/**
 * @typedef {(
 *   payload:Record<string,any>,
 *   options:UploadOptions
 * )=>Promise<UploadSuccessResponse>} UploadImplementation
 */

/**
 * @typedef UploadContextProviderProps
 *
 * @prop {UploadImplementation=} upload Custom upload implementation.
 * @prop {boolean=} isMockClient Whether to treat upload as a mock implementation.
 * @prop {Record<string,string>} backgroundUploadURLs URLs to which payload values corresponding to
 * key should be uploaded as soon as possible.
 * @prop {CryptoKey} backgroundUploadEncryptKey Background upload encryption key.
 * @prop {string} endpoint Endpoint to which payload should be sent.
 * @prop {string=} statusEndpoint Endpoint from which to request async upload status.
 * @prop {'POST'|'PUT'} method HTTP method to send payload.
 * @prop {string} csrf CSRF token to send as parameter to upload implementation.
 * @prop {Record<string,any>} formData Extra form data to merge into the payload before uploading
 * @prop {ReactNode} children Child elements.
 */

/**
 * @param {UploadContextProviderProps} props Props object.
 */
function UploadContextProvider({
  upload = defaultUpload,
  isMockClient = false,
  backgroundUploadURLs = {},
  backgroundUploadEncryptKey,
  endpoint,
  statusEndpoint,
  method,
  csrf,
  formData,
  children,
}) {
  const uploadWithCSRF = (payload) =>
    upload({ ...payload, ...formData }, { endpoint, method, csrf });

  const getStatus = () =>
    statusEndpoint
      ? upload(formData, { endpoint: statusEndpoint, method, csrf })
      : Promise.reject();

  const value = useMemo(
    () => ({
      upload: uploadWithCSRF,
      getStatus,
      backgroundUploadURLs,
      backgroundUploadEncryptKey,
      isMockClient,
    }),
    [upload, getStatus, backgroundUploadURLs, backgroundUploadEncryptKey, isMockClient],
  );

  return <UploadContext.Provider value={value}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
