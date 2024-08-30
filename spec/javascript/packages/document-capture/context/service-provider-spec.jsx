import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import ServiceProviderContext from '@18f/identity-document-capture/context/service-provider';

describe('document-capture/context/service-provider', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(ServiceProviderContext));

    expect(result.current).to.have.keys(['name', 'failureToProofURL']);
    expect(result.current.name).to.be.null();
    expect(result.current.failureToProofURL).to.be.a('string');
  });
});
