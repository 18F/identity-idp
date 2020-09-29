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

function getServiceProvider() {
  const name = appRoot.getAttribute('data-sp-name');
  const failureToProofURL = appRoot.getAttribute('data-failure-to-proof-url');
  const ial2Strict = appRoot.hasAttribute('data-ial2-strict');
  if (name && failureToProofURL) {
    return { name, failureToProofURL, ial2Strict };
  }
}

function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content ?? null;
}

/** @type {import('@18f/identity-document-capture/context/device').DeviceContext} */
const device = {
  isMobile: isCameraCapableMobile(),
};

loadPolyfills(['fetch']).then(() => {
  render(
    <AcuantProvider
      credentials={getMetaContent('acuant-sdk-initialization-creds')}
      endpoint={getMetaContent('acuant-sdk-initialization-endpoint')}
    >
      <UploadContextProvider
        endpoint={appRoot.getAttribute('data-endpoint')}
        csrf={getMetaContent('csrf-token')}
        isMockClient={isMockClient}
        formData={{
          document_capture_session_uuid: appRoot.getAttribute('data-document-capture-session-uuid'),
          locale: i18n.currentLocale(),
        }}
      >
        <I18nContext.Provider value={i18n.strings}>
          <ServiceProviderContext.Provider value={getServiceProvider()}>
            <AssetContext.Provider value={assets}>
              <DeviceContext.Provider value={device}>
                <DocumentCapture />
              </DeviceContext.Provider>
            </AssetContext.Provider>
          </ServiceProviderContext.Provider>
        </I18nContext.Provider>
      </UploadContextProvider>
    </AcuantProvider>,
    appRoot,
  );
});
