import { Button, StatusPage } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import type { PII } from '../services/upload';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';

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
  function skipAttention() {
    window.onbeforeunload = null;
    window.location.reload();
  }

  return (
    <StatusPage
      header={t('doc_auth.errors.barcode_attention.heading')}
      status="warning"
      actionButtons={[
        <Button key="continue" isBig isWide onClick={skipAttention}>
          {t('forms.buttons.continue')}
        </Button>,
        <Button key="add-new" isBig isOutline isWide onClick={onDismiss}>
          {t('doc_auth.buttons.add_new_photos')}
        </Button>,
      ]}
      troubleshootingOptions={
        <DocumentCaptureTroubleshootingOptions
          location="post_submission_warning"
          showDocumentTips={false}
          hasErrors
        />
      }
    >
      <p>{t('doc_auth.errors.barcode_attention.confirm_info')}</p>
      <dl className="add-list-reset">
        <div>
          <dt className="display-inline">{t('doc_auth.forms.first_name')}:</dt>
          <dd className="display-inline margin-left-05">{pii.first_name}</dd>
        </div>
        <div>
          <dt className="display-inline">{t('doc_auth.forms.last_name')}:</dt>
          <dd className="display-inline margin-left-05">{pii.last_name}</dd>
        </div>
        <div>
          <dt className="display-inline">{t('doc_auth.forms.dob')}:</dt>
          <dd className="display-inline margin-left-05">{pii.dob}</dd>
        </div>
      </dl>
    </StatusPage>
  );
}

export default BarcodeAttentionWarning;
