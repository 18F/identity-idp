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

it('shows the fullscreen close button before acuant is hydrated in', () => {
  // Render the AcuantSelfieCaptureCanvas component with some text
  const imageCaptureText = 'Face not found';
  const { rerender, container, queryByRole } = render(
    <DeviceContext.Provider value={{ isMobile: true }}>
      <AcuantContext.Provider value={{ isReady: true }}>
        <AcuantSelfieCaptureCanvas imageCaptureText={imageCaptureText} />
      </AcuantContext.Provider>
    </DeviceContext.Provider>,
  );
  // Check that the button exists
  expect(queryByRole('button')).to.exist();

  // Mock how Acuant sets up the dom by creating this structure of divs
  // '#acuant-face-capture-container>#acuant-face-capture-camera>#cameraContainer'
  const acuantFaceCaptureDiv = document.createElement('div');
  acuantFaceCaptureDiv.id = 'acuant-face-capture-camera';
  const acuantFaceCaptureContainer = container.querySelector('#acuant-face-capture-container');
  acuantFaceCaptureContainer.appendChild(acuantFaceCaptureDiv);
  expect(
    container.querySelector('#acuant-face-capture-container>#acuant-face-capture-camera'),
  ).to.exist();

  // Mock how Acuant sets up the shadow dom with the #cameraContainer div inside it
  const cameraContainer = document.createElement('div');
  cameraContainer.id = 'cameraContainer';
  const shadow = container
    .querySelector('#acuant-face-capture-camera')
    .attachShadow({ mode: 'open' });
  shadow.appendChild(cameraContainer);

  // Rerender the component, the shadow dom continues to exist
  const newImageCaptureText = 'Too many faces';
  rerender(
    <DeviceContext.Provider value={{ isMobile: true }}>
      <AcuantContext.Provider value={{ isReady: true }}>
        <AcuantSelfieCaptureCanvas imageCaptureText={newImageCaptureText} />
      </AcuantContext.Provider>
    </DeviceContext.Provider>,
  );
  // The button now disappears
  expect(queryByRole('button')).not.to.exist();
});
