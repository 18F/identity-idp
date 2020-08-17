import React, { useState, useEffect } from 'react';
import useIfStillMounted from '../hooks/use-if-still-mounted';

/**
 * @typedef FileImageProps
 *
 * @prop {Blob} file Image file.
 * @prop {string} alt Image alt text.
 * @prop {string=} className Optional class name.
 */

/**
 * @param {FileImageProps} props Props object.
 */
function FileImage({ file, alt, className }) {
  const [imageData, setImageData] = useState(/** @type {string?} */ (null));
  const ifStillMounted = useIfStillMounted();

  useEffect(() => {
    const reader = new window.FileReader();
    reader.onload = ifStillMounted(({ target }) => setImageData(target.result));
    reader.readAsDataURL(file);
  }, [file]);

  return imageData ? <img src={imageData} alt={alt} className={className} /> : null;
}

export default FileImage;
