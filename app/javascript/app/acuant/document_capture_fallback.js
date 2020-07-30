// eslint-disable-next-line import/no-cycle
import {
  showAcuantSdkFallbackText,
  addClickEventListenerToAcuantFallbackLink,
  acauntDocumentCaptureFallbackEnabled,
} from './document_capture_dom';

export const enableDocumentCaptureFallbackMode = () => {
  window.isDocumentCaptureFallbackModeEnabled = true;
  acauntDocumentCaptureFallbackEnabled();
};

export const documentCaptureFallbackModeEnabled = () =>
  window.isDocumentCaptureFallbackModeEnabled === true;

export const documentCaptureFallbackLinkClicked = (event) => {
  event.preventDefault();
  enableDocumentCaptureFallbackMode();
};

export const setDocumentCaptureFallbackTimeout = () => {
  addClickEventListenerToAcuantFallbackLink(documentCaptureFallbackLinkClicked);
  window.setTimeout(() => {
    showAcuantSdkFallbackText();
  }, 5000);
};
