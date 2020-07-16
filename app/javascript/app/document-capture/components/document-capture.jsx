import React from 'react';
import DocumentTips from './document-tips';
import Image from './image';
import useI18n from '../hooks/use-i18n';

function DocumentCapture() {
  const t = useI18n();

  const sample = (
    <Image
      assetPath="state-id-sample-front.jpg"
      alt="Sample front of state issued ID"
      width={450}
      height={338}
    />
  );

  return (
    <>
      <DocumentTips sample={sample} />
      {t('doc_auth.headings.welcome')}
    </>
  );
}

export default DocumentCapture;
