import React from 'react';
import { render } from 'react-dom';
import DocumentCapture from '../app/document-capture/components/document-capture';
import AssetContext from '../app/document-capture/context/asset';
import I18nContext from '../app/document-capture/context/i18n';
import DeviceContext from '../app/document-capture/context/device';
import { Provider as AcuantProvider } from '../app/document-capture/context/acuant';
import { Provider as UploadContextProvider } from '../app/document-capture/context/upload';

const { I18n: i18n, assets } = window.LoginGov;

function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content ?? null;
}

/** @type {import('../app/document-capture/context/device').DeviceContext} */
const device = {
  isMobile:
    'mediaDevices' in window.navigator &&
    /ip(hone|ad|od)|android/i.test(window.navigator.userAgent),
};

const appRoot = document.getElementById('document-capture-form');
appRoot.innerHTML = '';
render(
  <AcuantProvider
    credentials={getMetaContent('acuant-sdk-initialization-creds')}
    endpoint={getMetaContent('acuant-sdk-initialization-endpoint')}
  >
    <I18nContext.Provider value={i18n.strings[i18n.currentLocale()]}>
      <UploadContextProvider csrf={getMetaContent('csrf-token')}>
        <AssetContext.Provider value={assets}>
          <DeviceContext.Provider value={device}>
            <DocumentCapture />
          </DeviceContext.Provider>
        </AssetContext.Provider>
      </UploadContextProvider>
    </I18nContext.Provider>
  </AcuantProvider>,
  appRoot,
);
