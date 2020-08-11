import React from 'react';
import { render } from 'react-dom';
import {
  DocumentCapture,
  AssetContext,
  I18nContext,
  DeviceContext,
  AcuantProvider,
} from '@18f/identity-document-capture';

const { I18n: i18n, assets } = window.LoginGov;

function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content ?? null;
}

/** @type {import('../packages/document-capture/context/device').DeviceContext} */
const device = {
  isMobile:
    'mediaDevices' in window.navigator &&
    /ip(hone|ad|od)|android/i.test(window.navigator.userAgent),
};

const appRoot = document.getElementById('document-capture-form');
const isLivenessEnabled = appRoot.hasAttribute('data-liveness');
render(
  <AcuantProvider
    credentials={getMetaContent('acuant-sdk-initialization-creds')}
    endpoint={getMetaContent('acuant-sdk-initialization-endpoint')}
  >
    <I18nContext.Provider value={i18n.strings}>
      <AssetContext.Provider value={assets}>
        <DeviceContext.Provider value={device}>
          <DocumentCapture isLivenessEnabled={isLivenessEnabled} />
        </DeviceContext.Provider>
      </AssetContext.Provider>
    </I18nContext.Provider>
  </AcuantProvider>,
  appRoot,
);
