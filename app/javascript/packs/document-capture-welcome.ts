import { trackEvent } from '@18f/identity-analytics';
import { hasCamera, isCameraCapableMobile } from '@18f/identity-device';

const GRACE_TIME_FOR_CAMERA_CHECK_MS = 2000;
const DEVICE_CHECK_EVENT = 'IdV: Mobile device and camera check';

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function measure<T>(func: () => Promise<T>): Promise<{ result: T; duration: number }> {
  const start = performance.now();
  const result = await func();
  const duration = performance.now() - start;
  return { result, duration };
}

function addFormInputsForMobileDeviceCapabilities() {
  const form = document.querySelector<HTMLFormElement>('.js-consent-continue-form');

  if (!form) {
    return;
  }

  if (!isCameraCapableMobile()) {
    trackEvent(DEVICE_CHECK_EVENT, {
      is_camera_capable_mobile: false,
    });
    return;
  }

  // The check for a camera on the device is async -- kick it off here and intercept
  // submit() to ensure that it completes in time.
  const cameraCheckPromise = measure(hasCamera).then(
    async ({ result: cameraPresent, duration }) => {
      if (cameraPresent) {
        // Signal to the backend that this is a mobile device with a camera,
        // and this user should skip the hybrid handoff ("upload") step.
        const input = document.createElement('input');
        input.type = 'hidden';
        input.name = 'skip_upload';
        form.appendChild(input);
      }

      await trackEvent(DEVICE_CHECK_EVENT, {
        is_camera_capable_mobile: true,
        camera_present: !!cameraPresent,
        grace_time: GRACE_TIME_FOR_CAMERA_CHECK_MS,
        duration: Math.floor(duration),
      });
    },
  );

  form.addEventListener('submit', (event) => {
    event.preventDefault();

    for (const spinner of form.querySelectorAll('lg-spinner-button')) {
      spinner.toggleSpinner(true);
    }

    Promise.race([delay(GRACE_TIME_FOR_CAMERA_CHECK_MS), cameraCheckPromise]).then(() =>
      form.submit(),
    );
  });
}

addFormInputsForMobileDeviceCapabilities();
