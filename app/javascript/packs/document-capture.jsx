import React from 'react';
import { render } from 'react-dom';
import DocumentCapture from '../app/document-capture/components/document-capture';
import I18nContext from '../app/document-capture/context/i18n';

const { I18n: i18n } = window.LoginGov;

const appRoot = document.getElementById('document-capture-form');
appRoot.innerHTML = '';
render(
  <I18nContext.Provider value={i18n.strings[i18n.currentLocale()]}>
    <DocumentCapture />
  </I18nContext.Provider>,
  appRoot,
);
