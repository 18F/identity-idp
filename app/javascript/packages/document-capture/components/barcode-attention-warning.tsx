import { Button, StatusPage } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { trackEvent } from '@18f/identity-analytics';
import { useContext } from 'react';
import { removeUnloadProtection } from '@18f/identity-url';
import type { PII } from '../services/upload';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';
import SelfieCaptureContext from '../context/selfie-capture';

interface BarcodeAttentionWarningProps {
  /**
   * Callback to trigger when user opts to try to take new photos rather than continue to next step.
   */
  onDismiss: () => void;

  /**
   * Personally-identifiable information for user to verify.
   */
  pii: PII;
}

function BarcodeAttentionWarning({ onDismiss, pii }: BarcodeAttentionWarningProps) {
  const { isSelfieCaptureEnabled } = useContext(SelfieCaptureContext);
  function skipAttention() {
    trackEvent('IdV: barcode warning continue clicked', {
      liveness_checking_required: isSelfieCaptureEnabled,
    });
    removeUnloadProtection();
    const form = document.querySelector<HTMLFormElement>('.js-document-capture-form');
    form?.submit();
  }

  function handleDismiss() {
    trackEvent('IdV: barcode warning retake photos clicked', {
      liveness_checking_required: isSelfieCaptureEnabled,
    });
    onDismiss();
  }

  return (
    <StatusPage
      header={t('doc_auth.errors.barcode_attention.heading')}
      status="warning"
      actionButtons={[
        <Button key="continue" isBig isWide onClick={skipAttention}>
          {t('forms.buttons.continue')}
        </Button>,
        <Button key="add-new" isBig isOutline isWide onClick={handleDismiss}>
          {t('doc_auth.buttons.add_new_photos')}
        </Button>,
      ]}
      troubleshootingOptions={
        <DocumentCaptureTroubleshootingOptions
          location="post_submission_warning"
          showDocumentTips={false}
        />
      }
    >
      <p>{t('doc_auth.errors.barcode_attention.confirm_info')}</p>
      <dl className="add-list-reset">
        <div>
          <dt className="display-inline">{t('idv.form.first_name')}:</dt>
          <dd className="display-inline margin-left-05">{pii.first_name}</dd>
        </div>
        <div>
          <dt className="display-inline">{t('idv.form.last_name')}:</dt>
          <dd className="display-inline margin-left-05">{pii.last_name}</dd>
        </div>
        <div>
          <dt className="display-inline">{t('idv.form.dob')}:</dt>
          <dd className="display-inline margin-left-05">{pii.dob}</dd>
        </div>
      </dl>
    </StatusPage>
  );
}

export default BarcodeAttentionWarning;
