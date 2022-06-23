import { trackEvent } from '@18f/identity-analytics';

const downloadLink = document.querySelector('a[download]');

function trackDownload() {
  trackEvent('Multi-Factor Authentication: download backup code');
}

downloadLink?.addEventListener('click', trackDownload);
