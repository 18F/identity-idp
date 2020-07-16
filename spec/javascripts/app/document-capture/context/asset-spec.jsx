import React, { useContext } from 'react';
import { render } from '@testing-library/react';
import AssetContext from '../../../../../app/javascript/app/document-capture/context/asset';
import { useDOM } from '../../../support/dom';

describe('document-capture/context/asset', () => {
  useDOM();

  const ContextValue = () => JSON.stringify(useContext(AssetContext));

  it('defaults to empty object', () => {
    const { container } = render(<ContextValue />);

    expect(container.textContent).to.equal('{}');
  });
});
