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
const acknowledgmentCheckbox = document.getElementById('acknowledgment');

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

function downloadForIE(event) {
  event.preventDefault();

  const filename = downloadLink.getAttribute('download');
  const data = scrapePersonalKey();
  const blob = new Blob([data], { type: 'text/plain' });

  window.navigator.msSaveBlob(blob, filename);
}

function trackAcknowledgment(clickEvent) {
  if (clickEvent.target.checked) {
    trackEvent('IdV: personal key acknowledged');
  } else {
    trackEvent('IdV: personal key un-acknowledged');
  }
}

function trackDownload() {
  trackEvent('IdV: download personal key');
}

downloadLink.addEventListener('click', trackDownload);
acknowledgmentCheckbox.addEventListener('click', trackAcknowledgment);

if (window.navigator.msSaveBlob) {
  downloadLink.addEventListener('click', downloadForIE);
}
