import { encodeInput } from '@18f/identity-personal-key-input';
import { trackEvent } from '@18f/identity-analytics';
import { t } from '@18f/identity-i18n';

const modalSelector = '#personal-key-confirm';
const modal = new window.LoginGov.Modal({ el: modalSelector });

const personalKeyWords = [].slice.call(document.querySelectorAll('[data-personal-key]'));
const formEl = document.getElementById('confirm-key');
const input = formEl.querySelector('input[type="text"]');
const modalTrigger = document.querySelector('[data-toggle="modal"]');
const modalDismiss = document.querySelector('[data-dismiss="personal-key-confirm"]');
const downloadLink = document.querySelector('a[download]');

function scrapePersonalKey() {
  const keywords = [];

  personalKeyWords.forEach((keyword) => {
    keywords.push(keyword.innerHTML);
  });

  return keywords.join('-').toUpperCase();
}

const personalKey = scrapePersonalKey();

function resetForm() {
  formEl.reset();
  input.setCustomValidity('');
}

function validateInput() {
  const value = encodeInput(input.value);
  const isValid = value === personalKey;
  input.setCustomValidity(isValid ? '' : t('users.personal_key.confirmation_error'));
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

function trackDownload() {
  trackEvent('IdV: download personal key');
}

if (modalTrigger) {
  modalTrigger.addEventListener('click', show);
}
modalDismiss.addEventListener('click', hide);
input.addEventListener('input', validateInput);
downloadLink.addEventListener('click', trackDownload);

if (window.navigator.msSaveBlob) {
  downloadLink.addEventListener('click', downloadForIE);
}
