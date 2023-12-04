import AcuantSelfieCaptureCanvas from '@18f/identity-document-capture/components/acuant-selfie-capture-canvas';
import { AcuantContext, DeviceContext } from '@18f/identity-document-capture';
import { render } from '../../../support/document-capture';

it('shows the loading spinner when the script hasnt loaded', () => {
  const { getByRole, container } = render(
    <DeviceContext.Provider value={{ isMobile: true }}>
      <AcuantContext.Provider value={{ isReady: false }}>
        <AcuantSelfieCaptureCanvas />
      </AcuantContext.Provider>
    </DeviceContext.Provider>,
  );

  expect(getByRole('dialog')).to.be.ok();
  expect(container.querySelector('#acuant-face-capture-container')).to.not.exist();
});

it('shows the Acuant div when the script has loaded', () => {
  const { queryByRole, container } = render(
    <DeviceContext.Provider value={{ isMobile: true }}>
      <AcuantContext.Provider value={{ isReady: true }}>
        <AcuantSelfieCaptureCanvas />
      </AcuantContext.Provider>
    </DeviceContext.Provider>,
  );

  expect(queryByRole('dialog')).to.not.exist();
  expect(container.querySelector('#acuant-face-capture-container')).to.exist();
});
