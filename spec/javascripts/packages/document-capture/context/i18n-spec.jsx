import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import I18nContext from '@18f/identity-document-capture/context/i18n';

describe('document-capture/context/i18n', () => {
  it('defaults to empty object', () => {
    const { result } = renderHook(() => useContext(I18nContext));

    expect(result.current).to.deep.equal({});
  });
});
