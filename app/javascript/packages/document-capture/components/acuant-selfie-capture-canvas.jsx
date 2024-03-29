import { useContext, useEffect } from 'react';
import { getAssetPath } from '@18f/identity-assets';
import { useI18n } from '@18f/identity-react-i18n';
import AcuantContext from '../context/acuant';

function LoadingSpinner() {
  return (
    <img
      src={getAssetPath('loading-badge.gif')}
      alt=""
      width="144"
      height="144"
      className="acuant-capture-canvas__spinner"
    />
  );
}

function AcuantSelfieCaptureCanvas({ imageCaptureText, onSelfieCaptureClosed }) {
  const { isReady } = useContext(AcuantContext);
  const { t } = useI18n();
  // The Acuant SDK script AcuantPassiveLiveness attaches to whatever element has
  // this id. It then uses that element as the root for the full screen selfie capture
  const acuantCaptureContainerId = 'acuant-face-capture-container';

  // The Acuant SDK doesn't include appropriate aria-labels. This is a hack to monitor the page
  // until the Acuant SDK adds specific elements, then attach an aria-label to those elements
  useEffect(() => {
    const findElementAndAddAriaLabel = (shadowRoot, selector, label) => {
      const closeTextButton = shadowRoot.querySelector(selector);
      if (closeTextButton) {
        closeTextButton.setAttribute('aria-label', label);
      }
    };

    // Stop retrying after an arbitrary number of times
    const maxRetrys = 10;
    let retries = 0;
    const intervalId = setInterval(() => {
      // Find the div that Acuant attaches the capture pane to, then retrieve the capture pane (shadowRoot)
      // https://developer.mozilla.org/en-US/docs/Web/API/Web_components/Using_shadow_DOM
      const shadowRoot = document.querySelector('#acuant-face-capture-camera')?.shadowRoot;

      if (shadowRoot) {
        // Find and label the top right corner white "close" text buton that closes the capture
        findElementAndAddAriaLabel(shadowRoot, 'div.close', 'close-text-button-aria-label');
        // Find and label the red "capture" icon button that shows the preview, but does not close the window
        findElementAndAddAriaLabel(shadowRoot, 'button.shoot', 'capture-button-aria-label');
        // Find and label the green checkmark captuure icon button that finalizes the selfie and closes the window
        findElementAndAddAriaLabel(shadowRoot, 'img.shoot', 'finish-capture-button-aria-label');
        // Stop the interval after adding the labels
        clearInterval(intervalId);
      }

      // Limit the number of times it can run
      retries += 1;
      if (retries >= maxRetrys) {
        // Stop the interval when maxRetrys is reached
        clearInterval(intervalId);
      }
      // This is how often to try finding the buttons in ms
    }, 500);
    // Stop looking for the buttons if the component gets unmounted while still looking
    return () => clearInterval(intervalId);
  });

  return (
    <>
      {!isReady && <LoadingSpinner />}
      <div id={acuantCaptureContainerId} />
      <p aria-live="assertive" className="document-capture-selfie-feedback">
        {imageCaptureText}
      </p>
      <button type="button" onClick={onSelfieCaptureClosed} className="usa-sr-only">
        {t('doc_auth.buttons.close')}
      </button>
    </>
  );
}

export default AcuantSelfieCaptureCanvas;
