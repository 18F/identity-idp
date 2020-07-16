import React from 'react';
import AcuantCapture from './acuant-capture';
import useI18n from '../hooks/use-i18n';

function DocumentCapture() {
  const t = useI18n();

  return (
    <>
      <h2>{t('doc_auth.headings.welcome')}</h2>
      <AcuantCapture />
    </>
  );
}

export default DocumentCapture;
