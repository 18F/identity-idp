import { Button, StatusPage } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import type { PII } from '../services/upload';
import DocumentCaptureTroubleshootingOptions from './document-capture-troubleshooting-options';

interface BarcodeAttentionWarningProps {
  onDismiss: () => void;

  pii: PII;
}

function BarcodeAttentionWarning({ onDismiss, pii }: BarcodeAttentionWarningProps) {
  function skipAttention() {
    window.onbeforeunload = null;
    window.location.reload();
  }

  // TODO: Translate
  // TODO: Troubleshooting options should only include "Get help at Partner Agency"

  return (
    <StatusPage
      header="We couldn’t read the barcode on your ID."
      status="warning"
      actionButtons={[
        <Button key="continue" isBig isWide onClick={skipAttention}>
          Continue
        </Button>,
        <Button key="add-new" isBig isOutline isWide onClick={onDismiss}>
          Add new photos
        </Button>,
      ]}
      troubleshootingOptions={
        <DocumentCaptureTroubleshootingOptions location="post_submission_warning" hasErrors />
      }
    >
      <p>
        If the information below is incorrect, please upload new photos of your state-issued ID.
      </p>
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
