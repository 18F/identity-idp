import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import ServiceProviderContext, {
  Provider,
} from '@18f/identity-document-capture/context/service-provider';

describe('document-capture/context/service-provider', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(ServiceProviderContext));

    expect(result.current).to.have.keys([
      'name',
      'failureToProofURL',
      'getFailureToProofURL',
      'selfieCaptureEnabled',
    ]);
    expect(result.current.name).to.be.null();
    expect(result.current.failureToProofURL).to.be.a('string');
    expect(result.current.getFailureToProofURL).to.be.a('function');
    expect(result.current.selfieCaptureEnabled).to.be.a('boolean');
  });

  describe('Provider', () => {
    it('customizes getFailureToProofURL to parameterize failureToProofURL location', () => {
      const { result } = renderHook(() => useContext(ServiceProviderContext), {
        wrapper: ({ children }) => (
          <Provider value={{ failureToProofURL: 'http://example.com/?a=1' }}>{children}</Provider>
        ),
      });

      const failureToProofURL = result.current.getFailureToProofURL('location name');

      expect(failureToProofURL).to.equal('http://example.com/?a=1&location=location+name');
    });
    it('provides selfieCaptureEnabled', () => {
      const { result } = renderHook(() => useContext(ServiceProviderContext), {
        wrapper: ({ children }) => <Provider selfieCaptureEnabled>{children}</Provider>,
      });

      const { selfieCaptureEnabled } = result.current;
      expect(selfieCaptureEnabled).to.equal(true);
    });
  });
});
