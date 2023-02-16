import { trackEvent } from '@18f/identity-analytics';
import { hasCamera, isCameraCapableMobile } from '@18f/identity-device';

const GRACE_TIME_FOR_CAMERA_CHECK_MS = 2000;
const DEVICE_CHECK_EVENT = 'Idv: Mobile device and camera check';

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function measure<T>(
  measureName: string,
  promise: Promise<T>,
): Promise<{ result: T; duration: number }> {
  performance.measure(measureName);
  const result = await promise;
  const { duration } = performance.measure(measureName, {
    end: performance.now(),
  });
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
      user_agent: navigator.userAgent,
    });
    return;
  }

  // The check for a camera on the device is async -- kick it off here and intercept
  // submit() to ensure that it completes in time.
  const cameraCheckPromise = measure(DEVICE_CHECK_EVENT, hasCamera()).then(
    ({ result: cameraPresent, duration }) => {
      trackEvent(DEVICE_CHECK_EVENT, {
        is_camera_capable_mobile: true,
        camera_present: !!cameraPresent,
        grace_time: GRACE_TIME_FOR_CAMERA_CHECK_MS,
        duration,
      });

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
    },
  );

  form.addEventListener('submit', (event) => {
    event.preventDefault();

    Promise.race([delay(GRACE_TIME_FOR_CAMERA_CHECK_MS), cameraCheckPromise]).then(() =>
      form.submit(),
    );
  });
}

addFormInputsForMobileDeviceCapabilities();
