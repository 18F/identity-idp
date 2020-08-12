import React, { useContext } from 'react';
import AssetContext from '@18f/identity-document-capture/context/asset';
import render from '../../../support/render';

describe('document-capture/context/asset', () => {
  const ContextValue = () => JSON.stringify(useContext(AssetContext));

  it('defaults to empty object', () => {
    const { container } = render(<ContextValue />);

    expect(container.textContent).to.equal('{}');
  });
});
