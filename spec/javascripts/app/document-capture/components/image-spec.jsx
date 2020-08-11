import React from 'react';
import render from '../../../support/render';
import Image from '../../../../../app/javascript/packages/document-capture/components/image';
import AssetContext from '../../../../../app/javascript/packages/document-capture/context/asset';

describe('document-capture/components/image', () => {
  it('renders the given assetPath as src if the asset is not known', () => {
    const { getByAltText } = render(<Image assetPath="unknown.png" alt="unknown" />);

    const img = getByAltText('unknown');

    expect(img.getAttribute('src')).to.equal('unknown.png');
  });

  it('renders an img at mapped src if known by context', () => {
    const { getByAltText } = render(
      <AssetContext.Provider value={{ 'icon.png': 'icon-12345.png' }}>
        <Image assetPath="icon.png" alt="icon" />
      </AssetContext.Provider>,
    );

    const img = getByAltText('icon');

    expect(img.getAttribute('src')).to.equal('icon-12345.png');
  });

  it('renders with given props', () => {
    const { getByAltText } = render(<Image assetPath="icon.png" alt="icon" width={50} />);

    const img = getByAltText('icon');

    expect(img.width).to.equal(50);
  });
});
