import React, { createElement } from 'react';
import useAsset from '@18f/identity-document-capture/hooks/use-asset';
import AssetContext from '@18f/identity-document-capture/context/asset';
import render from '../../../support/render';

describe('document-capture/hooks/use-asset', () => {
  describe('getAssetPath', () => {
    it('returns undefined if the asset is not known', () => {
      const { getByAltText } = render(
        createElement(() => {
          const { getAssetPath } = useAsset();
          return <img src={getAssetPath('unknown.png')} alt="unknown" />;
        }),
      );

      const img = getByAltText('unknown');

      expect(img.hasAttribute('src')).to.be.false();
    });

    it('returns mapped src if known by context', () => {
      const { getByAltText } = render(
        <AssetContext.Provider value={{ 'icon.png': 'icon-12345.png' }}>
          {createElement(() => {
            const { getAssetPath } = useAsset();
            return <img src={getAssetPath('icon.png')} alt="icon" />;
          })}
        </AssetContext.Provider>,
      );

      const img = getByAltText('icon');

      expect(img.getAttribute('src')).to.equal('icon-12345.png');
    });
  });
});
