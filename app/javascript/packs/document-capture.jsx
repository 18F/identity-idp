import React from 'react';
import { render } from 'react-dom';
import DocumentCapture from '../app/document-capture/components/document-capture';
import AssetContext from '../app/document-capture/context/asset';
import I18nContext from '../app/document-capture/context/i18n';
import { Provider as AcuantProvider } from '../app/document-capture/context/acuant';

const { I18n: i18n, assets } = window.LoginGov;

function getMetaContent(name) {
  return document.querySelector(`meta[name="${name}"]`)?.content ?? null;
}

const appRoot = document.getElementById('document-capture-form');
appRoot.innerHTML = '';
render(
  <AcuantProvider
    credentials={getMetaContent('acuant-sdk-initialization-creds')}
    endpoint={getMetaContent('acuant-sdk-initialization-endpoint')}
  >
    <I18nContext.Provider value={i18n.strings[i18n.currentLocale()]}>
      <AssetContext.Provider value={assets}>
        <DocumentCapture />
      </AssetContext.Provider>
    </I18nContext.Provider>
  </AcuantProvider>,
  appRoot,
);
