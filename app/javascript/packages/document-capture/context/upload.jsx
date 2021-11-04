import { createContext, useMemo } from 'react';
import defaultUpload from '../services/upload';

const UploadContext = createContext({
  upload: defaultUpload,
  getStatus: /** @type {() => Promise<UploadSuccessResponse>} */ (() => Promise.reject()),
  statusPollInterval: /** @type {number=} */ (undefined),
  isMockClient: false,
  backgroundUploadURLs: /** @type {Record<string,string>} */ ({}),
  backgroundUploadEncryptKey: /** @type {CryptoKey=} */ (undefined),
  flowPath: /** @type {FlowPath} */ ('standard'),
  startOverURL: /** @type {string} */ (''),
  cancelURL: /** @type {string} */ (''),
  csrf: /** @type {string} */ (''),
});

UploadContext.displayName = 'UploadContext';

/** @typedef {import('react').ReactNode} ReactNode */

/** @typedef {'standard'|'hybrid'} FlowPath */

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
 * @prop {CryptoKey=} backgroundUploadEncryptKey Background upload encryption key.
 * @prop {string} endpoint Endpoint to which payload should be sent.
 * @prop {string=} statusEndpoint Endpoint from which to request async upload status.
 * @prop {number=} statusPollInterval Interval at which to poll for status, in milliseconds.
 * @prop {'POST'|'PUT'} method HTTP method to send payload.
 * @prop {string} csrf CSRF token to send as parameter to upload implementation.
 * @prop {Record<string,any>=} formData Extra form data to merge into the payload before uploading
 * @prop {FlowPath} flowPath The user's session flow path, one of "standard" or "hybrid".
 * @prop {string} startOverURL URL to application DELETE path for session restart.
 * @prop {string} cancelURL URL to application path for session cancel.
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
  statusPollInterval,
  method,
  csrf,
  formData,
  flowPath,
  startOverURL,
  cancelURL,
  children,
}) {
  const uploadWithCSRF = (payload) =>
    upload({ ...payload, ...formData }, { endpoint, method, csrf });

  const getStatus = () =>
    statusEndpoint
      ? upload({ ...formData }, { endpoint: statusEndpoint, method, csrf })
      : Promise.reject();

  const value = useMemo(
    () => ({
      upload: uploadWithCSRF,
      getStatus,
      statusPollInterval,
      backgroundUploadURLs,
      backgroundUploadEncryptKey,
      isMockClient,
      flowPath,
      startOverURL,
      cancelURL,
      csrf,
    }),
    [
      upload,
      getStatus,
      statusPollInterval,
      backgroundUploadURLs,
      backgroundUploadEncryptKey,
      isMockClient,
      flowPath,
      startOverURL,
      cancelURL,
      csrf,
    ],
  );

  return <UploadContext.Provider value={value}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
