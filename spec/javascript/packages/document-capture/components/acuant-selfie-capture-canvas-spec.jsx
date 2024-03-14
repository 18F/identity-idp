import AcuantSelfieCaptureCanvas from '@18f/identity-document-capture/components/acuant-selfie-capture-canvas';
import { AcuantContext, DeviceContext } from '@18f/identity-document-capture';
import { render } from '../../../support/document-capture';

it('shows the loading spinner when the script hasnt loaded', () => {
  const { container } = render(
    <DeviceContext.Provider value={{ isMobile: true }}>
      <AcuantContext.Provider value={{ isReady: false }}>
        <AcuantSelfieCaptureCanvas />
      </AcuantContext.Provider>
    </DeviceContext.Provider>,
  );

  expect(container.querySelector('#acuant-face-capture-container')).to.exist();
  expect(container.querySelector('.acuant-capture-canvas__spinner')).to.exist();
});

it('shows the Acuant div when the script has loaded', () => {
  const { container } = render(
    <DeviceContext.Provider value={{ isMobile: true }}>
      <AcuantContext.Provider value={{ isReady: true }}>
        <AcuantSelfieCaptureCanvas />
      </AcuantContext.Provider>
    </DeviceContext.Provider>,
  );

  expect(container.querySelector('#acuant-face-capture-container')).to.exist();
  expect(container.querySelector('.acuant-capture-canvas__spinner')).not.to.exist();
});
