import React, { useContext } from 'react';
import AssetContext from '../context/asset';

/**
 * @typedef ImageProps
 *
 * @prop {string} assetPath Asset path to resolve.
 * @prop {string} alt       Image alt attribute.
 */

/**
 * @param {ImageProps & Record<string,any>} props Props object.
 */
function Image({ assetPath, alt, ...imgProps }) {
  const assets = useContext(AssetContext);

  const src = Object.prototype.hasOwnProperty.call(assets, assetPath)
    ? assets[assetPath]
    : assetPath;

  // Disable reason: While props spreading can introduce confusion to what is
  // being passed down, in this case the component is intended to represent a
  // pass-through to a base `<img />` element, with handling for asset paths.
  //
  // Seee: https://github.com/airbnb/javascript/tree/master/react#props

  // eslint-disable-next-line react/jsx-props-no-spreading
  return <img src={src} alt={alt} {...imgProps} />;
}

export default Image;
