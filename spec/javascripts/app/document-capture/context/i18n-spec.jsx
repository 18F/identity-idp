import React, { useContext } from 'react';
import render from '../../../support/render';
import I18nContext from '@18f/identity-document-capture/context/i18n';

describe('document-capture/context/i18n', () => {
  const ContextValue = () => JSON.stringify(useContext(I18nContext));

  it('defaults to empty object', () => {
    const { container } = render(<ContextValue />);

    expect(container.textContent).to.equal('{}');
  });
});
