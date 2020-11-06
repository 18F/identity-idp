import React from 'react';
import { render } from 'react-dom';
import {
  DocumentCapture,
  AssetContext,
  I18nContext,
  DeviceContext,
  AcuantProvider,
  UploadContextProvider,
  ServiceProviderContext,
} from '@18f/identity-document-capture';
import { loadPolyfills } from '@18f/identity-polyfill';
import { isCameraCapableMobile } from '@18f/identity-device';

const { I18n: i18n, assets } = window.LoginGov;

const appRoot = document.getElementById('document-capture-form');
const isMockClient = appRoot.hasAttribute('data-mock-client');

/**
 * @return {import(
 *   '@18f/identity-document-capture/context/service-provider'
 * ).ServiceProviderContext}
 */
function getServiceProvider() {
  const name = appRoot.getAttribute('data-sp-name');
  const failureToProofURL = appRoot.getAttribute('data-failure-to-proof-url');
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
  }, {});
}

function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content ?? null;
}

/** @type {import('@18f/identity-document-capture/context/device').DeviceContext} */
const device = {
  isMobile: isCameraCapableMobile(),
};

loadPolyfills(['fetch', 'crypto']).then(async () => {
  const backgroundUploadURLs = getBackgroundUploadURLs();
  const isAsyncForm = Object.keys(backgroundUploadURLs).length > 0;

  const formData = {
    document_capture_session_uuid: appRoot.getAttribute('data-document-capture-session-uuid'),
    locale: i18n.currentLocale(),
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

  render(
    <AcuantProvider
      credentials={getMetaContent('acuant-sdk-initialization-creds')}
      endpoint={getMetaContent('acuant-sdk-initialization-endpoint')}
    >
      <UploadContextProvider
        endpoint={appRoot.getAttribute('data-endpoint')}
        statusEndpoint={appRoot.getAttribute('data-status-endpoint')}
        method={isAsyncForm ? 'PUT' : 'POST'}
        csrf={getMetaContent('csrf-token')}
        isMockClient={isMockClient}
        backgroundUploadURLs={backgroundUploadURLs}
        backgroundUploadEncryptKey={backgroundUploadEncryptKey}
        formData={formData}
      >
        <I18nContext.Provider value={i18n.strings}>
          <ServiceProviderContext.Provider value={getServiceProvider()}>
            <AssetContext.Provider value={assets}>
              <DeviceContext.Provider value={device}>
                <DocumentCapture isAsyncForm={isAsyncForm} />
              </DeviceContext.Provider>
            </AssetContext.Provider>
          </ServiceProviderContext.Provider>
        </I18nContext.Provider>
      </UploadContextProvider>
    </AcuantProvider>,
    appRoot,
  );
});
