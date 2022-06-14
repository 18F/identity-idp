import { trackEvent } from '@18f/identity-analytics';

const downloadLink = document.querySelector('a[download]');

function trackDownload() {
  trackEvent('IdV: download backup codes');
}

downloadLink?.addEventListener('click', trackDownload);
