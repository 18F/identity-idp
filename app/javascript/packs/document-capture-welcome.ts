import { hasCamera, isCameraCapableMobile } from '@18f/identity-device';

const form = document.querySelector('.js-consent-continue-form');

if (form && isCameraCapableMobile()) {
  (async () => {
    if (!(await hasCamera())) {
      const ncInput = document.createElement('input');
      ncInput.type = 'hidden';
      ncInput.name = 'no_camera';
      form.appendChild(ncInput);
    }
  })();

  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'skip_upload';
  form.appendChild(input);
}
