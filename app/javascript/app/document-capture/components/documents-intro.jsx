import React from 'react';
import useI18n from '../hooks/use-i18n';
import useDeviceHasVideoFacingMode from '../hooks/use-device-has-video-facing-mode';

function DocumentsIntro() {
  const isEnvironmentCaptureDevice = useDeviceHasVideoFacingMode('environment');
  const t = useI18n();

  return (
    <>
      <h1>{t('doc_auth.headings.take_pic_docs')}</h1>
      <p>{t('doc_auth.instructions.take_pic')}</p>
      <ul>
        <li>{t('doc_auth.instructions.take_pic1')}</li>
        <li>{t('doc_auth.instructions.take_pic2')}</li>
        <li>{t('doc_auth.instructions.take_pic3')}</li>
        {!isEnvironmentCaptureDevice && <li>{t('doc_auth.instructions.take_pic5')}</li>}
      </ul>
    </>
  );
}

export default DocumentsIntro;
