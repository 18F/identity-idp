import React from 'react';
import useI18n from '../hooks/use-i18n';

function MobileIntroStep() {
  const { t } = useI18n();

  return (
    <>
      <p>{t('doc_auth.info.document_capture_intro_acknowledgment')}</p>
      <p>
        <a href="/verify/jurisdiction/errors/no_id">{t('idv.messages.jurisdiction.no_id')}</a>
      </p>
      <p className="margin-bottom-0">{t('doc_auth.tips.document_capture_header_text')}</p>
      <ul>
        <li>{t('doc_auth.tips.document_capture_id_text1')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text2')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text3')}</li>
      </ul>
    </>
  );
}

export default MobileIntroStep;
