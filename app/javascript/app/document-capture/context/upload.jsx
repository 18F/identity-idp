import React, { createContext } from 'react';
import PropTypes from 'prop-types';
import defaultUpload from '../services/upload';

const UploadContext = createContext(defaultUpload);

function UploadContextProvider({ upload, csrf, children }) {
  const uploadWithCSRF = (payload) => upload(payload, csrf);

  return <UploadContext.Provider value={uploadWithCSRF}>{children}</UploadContext.Provider>;
}

UploadContextProvider.propTypes = {
  upload: PropTypes.func,
  csrf: PropTypes.string,
  children: PropTypes.node.isRequired,
};

UploadContextProvider.defaultProps = {
  upload: defaultUpload,
  csrf: undefined,
};

export default UploadContext;
export { UploadContextProvider as Provider };
