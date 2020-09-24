import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import ServiceProviderContext from '@18f/identity-document-capture/context/device';

describe('document-capture/context/service-provider', () => {
  it('defaults to undefined', () => {
    const { current } = renderHook(() => useContext(ServiceProviderContext));

    expect(current).to.be.undefined();
  });
});
