import React, { createContext } from 'react';
import defaultUpload from '../services/upload';

const UploadContext = createContext(defaultUpload);

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef UploadOptions
 *
 * @prop {string} endpoint Endpoint to which payload should be sent.
 * @prop {string} csrf CSRF token to send as parameter to upload implementation.
 * @prop {string} sessionUUID The UUID of the document capture session to write results to.
 */

/**
 * @typedef UploadSuccessResponse
 *
 * @prop {true} success Whether request was successful.
 */

/**
 * @typedef UploadErrorResponse
 *
 * @prop {false} success Whether request was successful.
 * @prop {string[]} errors Error messages.
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
 * @prop {string} endpoint Endpoint to which payload should be sent.
 * @prop {string} csrf CSRF token to send as parameter to upload implementation.
 * @prop {string} sessionUUID The UUID of the document capture session to write results to.
 * @prop {ReactNode} children Child elements.
 */

/**
 * @param {UploadContextProviderProps} props Props object.
 */
function UploadContextProvider({ upload = defaultUpload, endpoint, csrf, sessionUUID, children }) {
  const uploadWithCSRF = (payload) => upload(payload, { endpoint, csrf, sessionUUID });

  return <UploadContext.Provider value={uploadWithCSRF}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
