import React from 'react';
import useI18n from '../hooks/use-i18n';
import { useImage } from '../hooks/use-assets';

function DocumentCapture() {
  const t = useI18n();
  const imageTag = useImage();
  return <img src={imageTag('idv/phone.png')} alt={t('doc_auth.headings.welcome')} />;
}

export default DocumentCapture;
