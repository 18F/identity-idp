import { loadAndInitializeAcuantSdk } from '../app/acuant/sdk';

document.addEventListener('DOMContentLoaded', () => {
  window.ACUANT_SDK_INITIALIZATION_CREDS = document.querySelector(
    'meta[name="acuant-sdk-initialization-creds"]',
  ).content;
  window.ACUANT_SDK_INITIALIZATION_ENDPOINT = document.querySelector(
    'meta[name="acuant-sdk-initialization-endpoint"]',
  ).content;
  loadAndInitializeAcuantSdk();
});
