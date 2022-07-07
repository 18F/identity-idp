import { render } from 'react-dom';
import { composeComponents } from '@18f/identity-compose-components';
import {
  AppContext,
  DocumentCapture,
  DeviceContext,
  AcuantContextProvider,
  UploadContextProvider,
  ServiceProviderContextProvider,
  AnalyticsContext,
  FailedCaptureAttemptsContextProvider,
  HelpCenterContextProvider,
} from '@18f/identity-document-capture';
import { isCameraCapableMobile } from '@18f/identity-device';
import { FlowContext } from '@18f/identity-verify-flow';
import { trackEvent } from '@18f/identity-analytics';

/** @typedef {import('@18f/identity-document-capture').FlowPath} FlowPath */
/** @typedef {import('@18f/identity-i18n').I18n} I18n */

/**
 * @typedef LoginGov
 *
 * @prop {Record<string,string>} assets
 */

/**
 * @typedef LoginGovGlobals
 *
 * @prop {LoginGov} LoginGov
 */

/**
 * @typedef {typeof window & LoginGovGlobals} DocumentCaptureGlobal
 */

/**
 * @typedef AppRootData
 *
 * @prop {string} helpCenterRedirectUrl
 * @prop {string} appName
 * @prop {string} maxCaptureAttemptsBeforeTips
 * @prop {FlowPath} flowPath
 * @prop {string} cancelUrl
 * @prop {string=} idvInPersonUrl
 *
 * @see AppContext
 * @see HelpCenterContextProvider
 * @see FailedCaptureAttemptsContext
 * @see UploadContext
 */

const appRoot = /** @type {HTMLDivElement} */ (document.getElementById('document-capture-form'));
const isMockClient = appRoot.hasAttribute('data-mock-client');
const keepAliveEndpoint = /** @type {string} */ (appRoot.getAttribute('data-keep-alive-endpoint'));
const glareThreshold = Number(appRoot.getAttribute('data-glare-threshold')) ?? undefined;
const sharpnessThreshold = Number(appRoot.getAttribute('data-sharpness-threshold')) ?? undefined;

function getServiceProvider() {
  const { spName: name = null, failureToProofUrl: failureToProofURL = '' } = appRoot.dataset;
  const isLivenessRequired = appRoot.hasAttribute('data-liveness-required');

  return { name, failureToProofURL, isLivenessRequired };
}

/**
 * @return {Record<'front'|'back'|'selfie', string>}
 */
function getBackgroundUploadURLs() {
  return ['front', 'back', 'selfie'].reduce((result, key) => {
    const url = appRoot.getAttribute(`data-${key}-image-upload-url`);
    if (url) {
      result[key] = url;
    }

    return result;
  }, /** @type {Record<'front'|'back'|'selfie', string>} */ ({}));
}

/**
 * @return {string?}
 */
function getMetaContent(name) {
  const meta = /** @type {HTMLMetaElement?} */ (document.querySelector(`meta[name="${name}"]`));
  return meta?.content ?? null;
}

/** @type {import('@18f/identity-document-capture/context/device').DeviceContext} */
const device = {
  isMobile: isCameraCapableMobile(),
};

/** @type {import('@18f/identity-analytics').trackEvent} */
function addPageAction(event, payload) {
  const { flowPath } = appRoot.dataset;
  return trackEvent(event, { ...payload, flow_path: flowPath });
}

(async () => {
  const backgroundUploadURLs = getBackgroundUploadURLs();
  const isAsyncForm = Object.keys(backgroundUploadURLs).length > 0;
  const csrf = getMetaContent('csrf-token');

  const formData = {
    document_capture_session_uuid: appRoot.getAttribute('data-document-capture-session-uuid'),
    locale: document.documentElement.lang,
  };

  let backgroundUploadEncryptKey;
  if (isAsyncForm) {
    backgroundUploadEncryptKey = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );

    const exportedKey = await window.crypto.subtle.exportKey('raw', backgroundUploadEncryptKey);
    formData.encryption_key = btoa(String.fromCharCode(...new Uint8Array(exportedKey)));
    formData.step = 'verify_document';
  }

  const keepAlive = () =>
    window.fetch(keepAliveEndpoint, {
      method: 'POST',
      headers: /** @type {string[][]} */ ([csrf && ['X-CSRF-Token', csrf]].filter(Boolean)),
    });

  const {
    helpCenterRedirectUrl: helpCenterRedirectURL,
    maxCaptureAttemptsBeforeTips,
    appName,
    flowPath,
    cancelUrl: cancelURL,
    idvInPersonUrl: inPersonURL = null,
  } = /** @type {AppRootData} */ (appRoot.dataset);

  const App = composeComponents(
    [AppContext.Provider, { value: { appName } }],
    [HelpCenterContextProvider, { value: { helpCenterRedirectURL } }],
    [DeviceContext.Provider, { value: device }],
    [AnalyticsContext.Provider, { value: { addPageAction } }],
    [
      AcuantContextProvider,
      {
        credentials: getMetaContent('acuant-sdk-initialization-creds'),
        endpoint: getMetaContent('acuant-sdk-initialization-endpoint'),
        glareThreshold,
        sharpnessThreshold,
      },
    ],
    [
      UploadContextProvider,
      {
        endpoint: String(appRoot.getAttribute('data-endpoint')),
        statusEndpoint: String(appRoot.getAttribute('data-status-endpoint')),
        statusPollInterval: Number(appRoot.getAttribute('data-status-poll-interval-ms')),
        csrf,
        isMockClient,
        backgroundUploadURLs,
        backgroundUploadEncryptKey,
        formData,
        flowPath,
      },
    ],
    [
      FlowContext.Provider,
      {
        value: {
          cancelURL,
          inPersonURL,
          currentStep: 'document_capture',
        },
      },
    ],
    [ServiceProviderContextProvider, { value: getServiceProvider() }],
    [
      FailedCaptureAttemptsContextProvider,
      {
        maxFailedAttemptsBeforeTips: Number(maxCaptureAttemptsBeforeTips),
      },
    ],
    [DocumentCapture, { isAsyncForm, onStepChange: keepAlive }],
  );

  render(<App />, appRoot);
})();
