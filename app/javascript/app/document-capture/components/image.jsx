import React, { useContext } from 'react';
import PropTypes from 'prop-types';
import AssetContext from '../context/asset';

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

Image.propTypes = {
  assetPath: PropTypes.string.isRequired,
  alt: PropTypes.string.isRequired,
};

export default Image;
