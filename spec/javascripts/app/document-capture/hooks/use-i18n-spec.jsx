import React from 'react';
import { render } from '@testing-library/react';
import I18nContext from '../../../../../app/javascript/app/document-capture/context/i18n';
import useI18n from '../../../../../app/javascript/app/document-capture/hooks/use-i18n';

describe('document-capture/hooks/use-i18n', () => {
  const LocalizedString = ({ stringKey }) => useI18n()(stringKey);

  it('returns localized key value', () => {
    const { container } = render(
      <I18nContext.Provider value={{ sample: 'translation' }}>
        <LocalizedString stringKey="sample" />
      </I18nContext.Provider>,
    );

    expect(container.textContent).to.equal('translation');
  });

  it('falls back to key value', () => {
    const { container } = render(<LocalizedString stringKey="sample" />);

    expect(container.textContent).to.equal('sample');
  });
});
