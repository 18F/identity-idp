import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import SelfieCaptureContext from '@18f/identity-document-capture/context/selfie-capture';

describe('document-capture/context/feature-flag', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(SelfieCaptureContext));

    expect(result.current).to.have.keys(['isSelfieCaptureEnabled', 'isSelfieDesktopMode']);
    expect(result.current.isSelfieCaptureEnabled).to.be.a('boolean');
  });
});
