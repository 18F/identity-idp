import { hasCamera, isCameraCapableMobile } from '@18f/identity-device';

const GRACE_TIME_FOR_CAMERA_CHECK_MS = 2000;

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function addFormInputsForMobileDeviceCapabilities() {
  const form = document.querySelector<HTMLFormElement>('.js-consent-continue-form');

  if (!form) {
    return;
  }

  if (!isCameraCapableMobile()) {
    return;
  }

  // The check for a camera on the device is async -- kick it off here and intercept
  // submit() to ensure that it completes in time.
  let cameraPresent: boolean | undefined;
  const cameraCheckPromise = hasCamera().then((result: boolean) => {
    cameraPresent = !!result;

    if (!cameraPresent) {
      // Signal to the backend that this is a mobile device, but no camera is present
      const ncInput = document.createElement('input');
      ncInput.type = 'hidden';
      ncInput.name = 'no_camera';
      form.appendChild(ncInput);
    }

    // Signal to the backend that this is a mobile device, and this user should skip the
    // "hybrid handoff" step.
    const input = document.createElement('input');
    input.type = 'hidden';
    input.name = 'skip_upload';
    form.appendChild(input);

    return !!result;
  });

  form.addEventListener('submit', (event) => {
    if (cameraPresent != null) {
      // cameraCheckPromise has resolved. Form submission can continue...
      return;
    }

    // We don't have a "camera present" determination.
    // Give the computer a few seconds to return one, and proceed if it hasn't.

    event.preventDefault();

    for (const button of form.querySelectorAll(
      'button[type=submit]',
    ) as NodeListOf<HTMLButtonElement>) {
      button.disabled = true;
    }

    Promise.race([delay(GRACE_TIME_FOR_CAMERA_CHECK_MS), cameraCheckPromise]).then(() =>
      form.submit(),
    );
  });
}

addFormInputsForMobileDeviceCapabilities();
