import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import SelfieCaptureEnabledContext from '@18f/identity-document-capture/context/selfie-capture-enabled';

describe('document-capture/context/feature-flag', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(SelfieCaptureEnabledContext));

    expect(result.current).to.have.keys(['selfieCaptureEnabled']);
    expect(result.current.selfieCaptureEnabled).to.be.a('boolean');
  });
});
