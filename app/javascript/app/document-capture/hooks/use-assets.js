import { useContext } from 'react';
import AssetContext from '../context/assets';

function useImage() {
  const strings = useContext(AssetContext);
  const imageStrings = strings.images || {};
  const imageTag = (key) => {
    const resolvedImage = imageStrings[key];
    return resolvedImage !== undefined ? resolvedImage : key;
  };
  return imageTag;
}

export { useImage };
