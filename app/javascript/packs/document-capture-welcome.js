import { isCameraCapableMobile } from '@18f/identity-device';

const form = document.querySelector('form[action="/verify/doc_auth/welcome"]');

if (form && isCameraCapableMobile()) {
  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'skip_upload';
  form.appendChild(input);
}
