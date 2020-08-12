import React, { createContext } from 'react';
import defaultUpload from '../services/upload';

const UploadContext = createContext(defaultUpload);

/** @typedef {import('react').ReactNode} ReactNode */

/**
 * @typedef {(payload:Record<string,any>,csrf?:string)=>Promise<any>} UploadImplementation
 */

/**
 * @typedef UploadContextProviderProps
 *
 * @prop {UploadImplementation=} upload   Custom upload implementation.
 * @prop {string=}               csrf     CSRF token to send as parameter to upload implementation.
 * @prop {ReactNode}             children Child elements.
 */

/**
 * @param {UploadContextProviderProps} props Props object.
 */
function UploadContextProvider({ upload = defaultUpload, csrf, children }) {
  const uploadWithCSRF = (payload) => upload(payload, csrf);

  return <UploadContext.Provider value={uploadWithCSRF}>{children}</UploadContext.Provider>;
}

export default UploadContext;
export { UploadContextProvider as Provider };
