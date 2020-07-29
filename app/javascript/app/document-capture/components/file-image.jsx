import React, { useState, useEffect } from 'react';
import PropTypes from 'prop-types';
import useIfStillMounted from '../hooks/use-if-still-mounted';

function FileImage({ file, alt, ...imageProps }) {
  const [imageData, setImageData] = useState(null);
  const ifStillMounted = useIfStillMounted();

  useEffect(() => {
    const reader = new window.FileReader();
    reader.onload = ifStillMounted(({ target }) => setImageData(target.result));
    reader.readAsDataURL(file);
  }, [file]);

  // Disable reason: The component is intended to serve as a pass-through to a base `<img />`.
  // eslint-disable-next-line react/jsx-props-no-spreading
  return imageData ? <img src={imageData} alt={alt} {...imageProps} /> : null;
}

FileImage.propTypes = {
  file: PropTypes.instanceOf(window.File).isRequired,
  alt: PropTypes.string.isRequired,
};

export default FileImage;
