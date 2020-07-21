import React, { useContext } from 'react';
import { render } from '@testing-library/react';
import AssetContext from '../../../../../app/javascript/app/document-capture/context/asset';

describe('document-capture/context/asset', () => {
  const ContextValue = () => JSON.stringify(useContext(AssetContext));

  it('defaults to empty object', () => {
    const { container } = render(<ContextValue />);

    expect(container.textContent).to.equal('{}');
  });
});
