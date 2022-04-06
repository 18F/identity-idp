import { encodeInput } from '@18f/identity-personal-key-input';
import { trackEvent } from '@18f/identity-analytics';

const modalSelector = '#personal-key-confirm';
const modal = new window.LoginGov.Modal({ el: modalSelector });

const personalKeyWords = [].slice.call(document.querySelectorAll('[data-personal-key]'));
const formEl = document.getElementById('confirm-key');
const input = formEl.querySelector('input[type="text"]');
const modalTrigger = document.querySelector('[data-toggle="modal"]');
const modalDismiss = document.querySelector('[data-dismiss="personal-key-confirm"]');
const downloadLink = document.querySelector('a[download]');

let isInvalidForm = false;

function scrapePersonalKey() {
  const keywords = [];

  personalKeyWords.forEach((keyword) => {
    keywords.push(keyword.innerHTML);
  });

  return keywords.join('-').toUpperCase();
}

const personalKey = scrapePersonalKey();

// The following methods are strictly fallbacks for IE < 11. There is limited
// support for HTML5 validation attributes in those browsers
function setInvalidHTML() {
  if (isInvalidForm) {
    return;
  }

  document.getElementById('personal-key-alert').classList.remove('display-none');

  isInvalidForm = true;
}

function unsetInvalidHTML() {
  document.getElementById('personal-key-alert').classList.add('display-none');

  isInvalidForm = false;
}

function unsetEmptyResponse() {
  input.setAttribute('aria-invalid', 'false');
  input.classList.remove('margin-bottom-3');
  input.classList.add('margin-bottom-6');
  input.classList.remove('usa-input--error');

  isInvalidForm = false;
}

function resetErrors() {
  unsetEmptyResponse();
  unsetInvalidHTML();
}

function resetForm() {
  formEl.reset();
  resetErrors();
}

function setEmptyResponse() {
  input.setAttribute('aria-invalid', 'true');
  input.classList.remove('margin-bottom-6');
  input.classList.add('margin-bottom-3');
  input.classList.add('usa-input--error');
  input.focus();

  isInvalidForm = true;
}

function handleSubmit(event) {
  event.preventDefault();
  resetErrors();

  // As above, in case browser lacks HTML5 validation (e.g., IE < 11)
  if (input.value.length === 0) {
    setEmptyResponse();
    return;
  }

  const value = encodeInput(input.value);
  if (input.value.length < 19 || value !== personalKey) {
    setInvalidHTML();
    return;
  }

  // Recovery code page, without js enabled, has a form submission that posts
  // to the server with no body.
  // Mimic that here.
  formEl.removeEventListener('submit', handleSubmit);
  formEl.submit();
}

function show(event) {
  event.preventDefault();

  modal.on('show', function () {
    input.focus();
  });

  trackEvent('IdV: show personal key modal');
  modal.show();
}

function hide() {
  modal.on('hide', function () {
    resetForm();
  });

  trackEvent('IdV: hide personal key modal');
  modal.hide();
}

function downloadForIE(event) {
  event.preventDefault();

  const filename = downloadLink.getAttribute('download');
  const data = scrapePersonalKey();
  const blob = new Blob([data], { type: 'text/plain' });

  window.navigator.msSaveBlob(blob, filename);
}

modalTrigger.addEventListener('click', show);
modalDismiss.addEventListener('click', hide);
formEl.addEventListener('submit', handleSubmit);

if (window.navigator.msSaveBlob) {
  downloadLink.addEventListener('click', downloadForIE);
}
