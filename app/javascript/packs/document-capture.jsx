import React from 'react';
import { render } from 'react-dom';
import {
  DocumentCapture,
  AssetContext,
  I18nContext,
  DeviceContext,
  AcuantProvider,
  UploadContextProvider,
} from '@18f/identity-document-capture';
import { loadPolyfills } from '@18f/identity-polyfill';
import { isCameraCapableMobile } from '@18f/identity-device';

const { I18n: i18n, assets } = window.LoginGov;

function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content ?? null;
}

/** @type {import('@18f/identity-document-capture/context/device').DeviceContext} */
const device = {
  isMobile: isCameraCapableMobile(),
};

loadPolyfills(['fetch']).then(() => {
  const appRoot = document.getElementById('document-capture-form');
  const isLivenessEnabled = appRoot.hasAttribute('data-liveness');
  const isMockClient = appRoot.hasAttribute('data-mock-client');

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
          <AssetContext.Provider value={assets}>
            <DeviceContext.Provider value={device}>
              <DocumentCapture isLivenessEnabled={isLivenessEnabled} />
            </DeviceContext.Provider>
          </AssetContext.Provider>
        </I18nContext.Provider>
      </UploadContextProvider>
    </AcuantProvider>,
    appRoot,
  );
});
