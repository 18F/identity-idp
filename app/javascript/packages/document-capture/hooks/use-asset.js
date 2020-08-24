import { useContext } from 'react';
import AssetContext from '../context/asset';

function useAsset() {
  const assets = useContext(AssetContext);

  /**
   * Returns the mapped URL path associated with the given asset path. If the mapped URL path is not
   * known, the original path is returned.
   *
   * @param {string} assetPath Asset path.
   *
   * @return {string} Mapped URL path.
   */
  const getAssetPath = (assetPath) =>
    Object.prototype.hasOwnProperty.call(assets, assetPath) ? assets[assetPath] : assetPath;

  return { getAssetPath };
}

export default useAsset;
