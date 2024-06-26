import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { act } from '@testing-library/react';
import { AcuantContextProvider, DeviceContext } from '@18f/identity-document-capture';
import AcuantCaptureCanvas from '@18f/identity-document-capture/components/acuant-capture-canvas';
import { render, useAcuant } from '../../../support/document-capture';

describe('document-capture/components/acuant-capture-canvas', () => {
  const { initialize } = useAcuant();

  it('renders a "take photo" button', async () => {
    const { getByRole, container } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <AcuantCaptureCanvas />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    act(() => {
      initialize();
      window.AcuantCameraUI.start();
    });
    const button = getByRole('button', { name: 'doc_auth.buttons.take_picture' });

    expect(button.disabled).to.be.true();

    // This assumes that Acuant SDK will assign its own click handlers to respond to clicks on the
    // canvas, which happens in combination with assigning the callback property to the canvas.
    const canvas = container.querySelector('canvas');
    canvas.callback = () => {};

    expect(button.disabled).to.be.false();

    const onClick = sinon.spy();
    canvas.addEventListener('click', onClick);
    await userEvent.click(button);
    await userEvent.type(button, 'b {Enter}', { skipClick: true });
    expect(onClick).to.have.been.calledThrice();
  });
});
