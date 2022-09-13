const form = document.querySelector('.js-consent-continue-form');

if (form) {
  const input = document.createElement('input');
  input.type = 'hidden';
  input.name = 'skip_upload';
  form.appendChild(input);
}
