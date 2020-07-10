import React from 'react';
import { render } from 'react-dom';
import DocumentCapture from '../app/document-capture/components/document-capture';

const appRoot = document.getElementById('document-capture-form');
appRoot.innerHTML = '';
render(
  <DocumentCapture />,
  appRoot,
);
