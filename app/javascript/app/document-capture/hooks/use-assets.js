import { useContext } from 'react';
import AssetContext from '../context/assets';

function useImage() {
  const strings = useContext(AssetContext);
  const imageStrings = strings.images;
  const imageTag = (key) => {
    const resolvedImage = imageStrings[key];
    if (resolvedImage) {
      return resolvedImage;
    }
    console.error(`Image for ${key} not found`);
    return key;
  };
  return imageTag;
}

export { useImage };
