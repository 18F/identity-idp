import { useContext, useState, useEffect } from 'react';
import useIfStillMounted from '../hooks/use-if-still-mounted';
import FileBase64CacheContext from '../context/file-base64-cache';

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
  const cache = useContext(FileBase64CacheContext);
  const [, forceRender] = useState();
  const imageData = cache.get(file);
  const ifStillMounted = useIfStillMounted();

  useEffect(() => {
    const reader = new window.FileReader();
    reader.onload = ({ target }) => {
      cache.set(file, /** @type {string} */ (target?.result));
      ifStillMounted(forceRender)((prevState = 0) => 1 - prevState);
    };
    reader.readAsDataURL(file);
  }, [file]);

  const classes = [
    'document-capture-file-image',
    !imageData && 'document-capture-file-image--loading',
    className,
  ]
    .filter(Boolean)
    .join(' ');

  return imageData ? (
    <img src={imageData} alt={alt} className={classes} />
  ) : (
    <span className={classes} />
  );
}

export default FileImage;
