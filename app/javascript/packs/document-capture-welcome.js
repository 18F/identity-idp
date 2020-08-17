import { isCameraCapableMobile } from '@18f/identity-device';

const form = document.querySelector('.js-consent-form');

if (form && isCameraCapableMobile()) {
  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'skip_upload';
  form.appendChild(input);
}
