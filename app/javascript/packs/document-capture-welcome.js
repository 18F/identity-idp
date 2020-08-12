const form = document.querySelector('form[action="/verify/doc_auth/welcome"]');

// TODO:
//  Change to: import { isMobile } from '@18f/identity-device';
//  ...after:  https://github.com/18F/identity-idp/pull/4048
const isMobile =
  'mediaDevices' in window.navigator && /ip(hone|ad|od)|android/i.test(window.navigator.userAgent);

if (form && isMobile) {
  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'skip_upload';
  form.appendChild(input);
}
