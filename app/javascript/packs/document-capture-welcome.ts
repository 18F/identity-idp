import { isCameraCapableMobile } from '@18f/identity-device';

if (isCameraCapableMobile()) {
  const form = document.querySelector<HTMLFormElement>('.js-consent-continue-form')!;
  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'skip_upload';
  form.appendChild(input);
}
