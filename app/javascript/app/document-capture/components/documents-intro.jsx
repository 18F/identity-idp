import React from 'react';
import PageHeading from './page-heading';
import useI18n from '../hooks/use-i18n';
import useDeviceHasVideoFacingMode from '../hooks/use-device-has-video-facing-mode';

function DocumentsIntro() {
  const isEnvironmentCaptureDevice = useDeviceHasVideoFacingMode('environment');
  const t = useI18n();

  return (
    <>
      <PageHeading>{t('doc_auth.headings.take_pic_docs')}</PageHeading>
      <p className="margin-bottom-0">{t('doc_auth.instructions.take_pic')}</p>
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
