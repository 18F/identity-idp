import React from 'react';
import { Provider as AcuantContextProvider } from '@18f/identity-document-capture/context/acuant';
import AcuantCaptureCanvas from '@18f/identity-document-capture/components/acuant-capture-canvas';
import render from '../../../support/render';
import { useAcuant } from '../../../support/acuant';

describe('document-capture/components/acuant-capture-canvas', () => {
  const { initialize } = useAcuant();

  it('waits for initialization', () => {
    render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCaptureCanvas />
      </AcuantContextProvider>,
    );

    // At this point, it's assumed `window.AcuantCameraUI.start` has not been called. This can't be
    // asserted, since the global is only assigned as part of `initialize` itself. But we can rely
    // on the fact that if it was called, an error would be thrown, and the test would fail.

    initialize();

    expect(window.AcuantCameraUI.start.calledOnce).to.be.true();
  });

  it('ends on unmount', () => {
    const { unmount } = render(
      <AcuantContextProvider sdkSrc="about:blank">
        <AcuantCaptureCanvas />
      </AcuantContextProvider>,
    );

    initialize();
    unmount();

    expect(window.AcuantCameraUI.end.calledOnce).to.be.true();
  });
});
