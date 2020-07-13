import React, { useContext } from 'react';
import { render } from '@testing-library/react';
import I18nContext from '../../../../../app/javascript/app/document-capture/context/i18n';
import { useDOM } from '../../../support/dom';

describe('document-capture/context/i18n', () => {
  useDOM();

  const ContextValue = () => JSON.stringify(useContext(I18nContext));

  it('defaults to empty object', () => {
    const { container } = render(<ContextValue />);

    expect(container.textContent).to.equal('{}');
  });
});
