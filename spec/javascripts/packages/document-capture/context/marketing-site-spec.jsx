import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import MarketingSiteContext from '@18f/identity-document-capture/context/marketing-site';

describe('document-capture/context/marketing-site', () => {
  it('assigns default context', () => {
    const { result } = renderHook(() => useContext(MarketingSiteContext));

    expect(result.current).to.have.keys(['documentCaptureTipsURL']);
    expect(result.current.documentCaptureTipsURL).to.be.a('string');
  });
});
