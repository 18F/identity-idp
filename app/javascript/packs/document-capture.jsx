import { render } from 'react-dom';
import {
  AppContext,
  DocumentCapture,
  AssetContext,
  DeviceContext,
  AcuantContextProvider,
  UploadContextProvider,
  ServiceProviderContextProvider,
  AnalyticsContext,
} from '@18f/identity-document-capture';
import { loadPolyfills } from '@18f/identity-polyfill';
import { isCameraCapableMobile } from '@18f/identity-device';
import { trackEvent } from '@18f/identity-analytics';
import { I18nContext } from '@18f/identity-react-i18n';

/** @typedef {import('@18f/identity-i18n').I18n} I18n */

/**
 * @typedef NewRelicAgent
 *
 * @prop {(name:string,attributes:object)=>void} addPageAction Log page action to New Relic.
 * @prop {(error:Error)=>void} noticeError Log an error without affecting application behavior.
 */

/**
 * @typedef LoginGov
 *
 * @prop {I18n} I18n
 * @prop {Record<string,string>} assets
 */

/**
 * @typedef NewRelicGlobals
 *
 * @prop {NewRelicAgent=} newrelic New Relic agent.
 */

/**
 * @typedef LoginGovGlobals
 *
 * @prop {LoginGov} LoginGov
 */

/**
 * @typedef {typeof window & NewRelicGlobals & LoginGovGlobals} DocumentCaptureGlobal
 */

const { I18n: i18n, assets } = /** @type {DocumentCaptureGlobal} */ (window).LoginGov;

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

/** @type {import('@18f/identity-document-capture/context/analytics').AddPageAction} */
function addPageAction(action) {
  const { flowPath } = appRoot.dataset;
  const payload = { ...action.payload, flow_path: flowPath };

  const { newrelic } = /** @type {DocumentCaptureGlobal} */ (window);
  if (action.key && newrelic) {
    newrelic.addPageAction(action.key, payload);
  }

  trackEvent(action.label, payload);
}

/** @type {import('@18f/identity-document-capture/context/analytics').NoticeError} */
const noticeError = (error) =>
  /** @type {DocumentCaptureGlobal} */ (window).newrelic?.noticeError(error);

loadPolyfills(['fetch', 'crypto', 'url']).then(async () => {
  const backgroundUploadURLs = getBackgroundUploadURLs();
  const isAsyncForm = Object.keys(backgroundUploadURLs).length > 0;
  const csrf = /** @type {string} */ (getMetaContent('csrf-token'));

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
    window.fetch(keepAliveEndpoint, { method: 'POST', headers: { 'X-CSRF-Token': csrf } });

  const appContext = {
    appName: /** @type string */ (appRoot.dataset.appName),
  };

  render(
    <AppContext.Provider value={appContext}>
      <DeviceContext.Provider value={device}>
        <AnalyticsContext.Provider value={{ addPageAction, noticeError }}>
          <AcuantContextProvider
            credentials={getMetaContent('acuant-sdk-initialization-creds')}
            endpoint={getMetaContent('acuant-sdk-initialization-endpoint')}
            glareThreshold={glareThreshold}
            sharpnessThreshold={sharpnessThreshold}
          >
            <UploadContextProvider
              endpoint={/** @type {string} */ (appRoot.getAttribute('data-endpoint'))}
              statusEndpoint={/** @type {string} */ (appRoot.getAttribute('data-status-endpoint'))}
              statusPollInterval={
                Number(appRoot.getAttribute('data-status-poll-interval-ms')) || undefined
              }
              method={isAsyncForm ? 'PUT' : 'POST'}
              csrf={csrf}
              isMockClient={isMockClient}
              backgroundUploadURLs={backgroundUploadURLs}
              backgroundUploadEncryptKey={backgroundUploadEncryptKey}
              formData={formData}
            >
              <I18nContext.Provider value={i18n.strings}>
                <ServiceProviderContextProvider value={getServiceProvider()}>
                  <AssetContext.Provider value={assets}>
                    <DocumentCapture isAsyncForm={isAsyncForm} onStepChange={keepAlive} />
                  </AssetContext.Provider>
                </ServiceProviderContextProvider>
              </I18nContext.Provider>
            </UploadContextProvider>
          </AcuantContextProvider>
        </AnalyticsContext.Provider>
      </DeviceContext.Provider>
    </AppContext.Provider>,
    appRoot,
  );
});
