import { trackEvent } from '@18f/identity-analytics';

const modalSelector = '#personal-key-confirm';

const personalKeyWords = [].slice.call(document.querySelectorAll('[data-personal-key]'));
const formEl = document.getElementById('confirm-key');
const input = formEl.querySelector('input[type="text"]');
const downloadLink = document.querySelector('a[download]');
const acknowledgmentCheckbox = document.getElementById('acknowledgment');

function scrapePersonalKey() {
  const keywords = [];

  personalKeyWords.forEach((keyword) => {
    keywords.push(keyword.innerHTML);
  });

  return keywords.join('-').toUpperCase();
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
