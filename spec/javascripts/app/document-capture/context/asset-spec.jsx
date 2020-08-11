import React, { useContext } from 'react';
import render from '../../../support/render';
import AssetContext from '../../../../../app/javascript/packages/document-capture/context/asset';

describe('document-capture/context/asset', () => {
  const ContextValue = () => JSON.stringify(useContext(AssetContext));

  it('defaults to empty object', () => {
    const { container } = render(<ContextValue />);

    expect(container.textContent).to.equal('{}');
  });
});
