import { useContext } from 'react';
import { renderHook } from '@testing-library/react-hooks';
import SelfieCaptureContext from '@18f/identity-document-capture/context/selfie-capture';

describe('document-capture/context/selfie-capture', () => {
  it('has expected default properties', () => {
    const { result } = renderHook(() => useContext(SelfieCaptureContext));

    expect(result.current).to.have.keys([
      'isSelfieCaptureEnabled',
      'isSelfieDesktopTestMode',
      'showHelpInitially',
      'immediatelyBeginCapture',
    ]);
    expect(result.current.isSelfieCaptureEnabled).to.be.a('boolean');
  });
});
