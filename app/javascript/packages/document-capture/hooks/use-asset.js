import { useContext } from 'react';
import AssetContext from '../context/asset';

function useAsset() {
  const assets = useContext(AssetContext);

  /**
   * Returns the mapped URL path associated with the given asset path, or `undefined` if the mapped
   * URL path is not known.
   *
   * @param {string} assetPath Asset path.
   *
   * @return {string|undefined} Mapped URL path, or undefined if there is no associated asset path.
   */
  const getAssetPath = (assetPath) =>
    Object.prototype.hasOwnProperty.call(assets, assetPath) ? assets[assetPath] : undefined;

  return { getAssetPath };
}

export default useAsset;
