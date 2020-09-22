import React, { useContext } from 'react';
import ServiceProviderContext from '../context/service-provider';
import useI18n from '../hooks/use-i18n';

function MobileIntroStep() {
  const { t, formatHTML } = useI18n();
  const serviceProvider = useContext(ServiceProviderContext);

  return (
    <>
      <p>{t('doc_auth.info.document_capture_intro_acknowledgment')}</p>
      <p>
        {formatHTML(t('doc_auth.info.id_worn_html'), {
          strong: 'strong',
        })}{' '}
        <a href="/">{t('doc_auth.info.accepted_ids')}</a>
      </p>
      {serviceProvider && (
        <p>
          {formatHTML(t('doc_auth.info.no_other_id_help_bold', { sp_name: serviceProvider.name }), {
            'lg-strong': 'strong',
            'lg-get-help-link': ({ children }) => (
              <a href={serviceProvider.failureToProofURL}>{children}</a>
            ),
          })}
        </p>
      )}
      <p className="margin-top-4 margin-bottom-0">
        {t('doc_auth.tips.document_capture_header_text')}
      </p>
      <ul>
        <li>{t('doc_auth.tips.document_capture_id_text1')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text2')}</li>
        <li>{t('doc_auth.tips.document_capture_id_text3')}</li>
      </ul>
    </>
  );
}

export default MobileIntroStep;
