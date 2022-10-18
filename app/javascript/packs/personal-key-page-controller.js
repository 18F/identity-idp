import { trackEvent } from '@18f/identity-analytics';

const personalKeyWords = [].slice.call(document.querySelectorAll('[data-personal-key]'));
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
  trackEvent('IdV: personal key acknowledgment toggled', { checked: clickEvent.target.checked });
}

function trackDownload() {
  trackEvent('IdV: download personal key');
}

downloadLink.addEventListener('click', trackDownload);
acknowledgmentCheckbox.addEventListener('click', trackAcknowledgment);

if (window.navigator.msSaveBlob) {
  downloadLink.addEventListener('click', downloadForIE);
}
