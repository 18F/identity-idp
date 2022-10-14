import { trackEvent } from '@18f/identity-analytics';

const downloadLink = document.querySelector('a[download]');
const acknowledgmentCheckbox = document.getElementById('acknowledgment');

function trackAcknowledgment(clickEvent) {
  trackEvent('IdV: personal key acknowledgment toggled', { checked: clickEvent.target.checked });
}

function trackDownload() {
  trackEvent('IdV: download personal key');
}

downloadLink.addEventListener('click', trackDownload);
acknowledgmentCheckbox.addEventListener('click', trackAcknowledgment);
