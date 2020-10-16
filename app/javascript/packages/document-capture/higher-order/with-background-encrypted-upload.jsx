import React, { useContext } from 'react';
import UploadContext from '../context/upload';

const withBackgroundEncryptedUpload = (Component) => ({ onChange, ...props }) => {
  const { backgroundUploadURLs } = useContext(UploadContext);

  /**
   * @param {Record<string, string|Blob|null|undefined>} nextValues Next values.
   */
  function onChangeWithBackgroundEncryptedUpload(nextValues) {
    const nextValuesWithUpload = {};
    for (const [key, value] of Object.entries(nextValues)) {
      nextValuesWithUpload[key] = value;
      const url = backgroundUploadURLs[key];
      if (url && value) {
        nextValuesWithUpload[`${key}BackgroundUpload`] = window.fetch(url, {
          method: 'POST',
          body: value,
        });
      }
    }

    onChange(nextValuesWithUpload);
  }

  // eslint-disable-next-line react/jsx-props-no-spreading
  return <Component {...props} onChange={onChangeWithBackgroundEncryptedUpload} />;
};

export default withBackgroundEncryptedUpload;
