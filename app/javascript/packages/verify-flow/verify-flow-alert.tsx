import { t } from '@18f/identity-i18n';
import { Alert } from '@18f/identity-components';

interface VerifyFlowAlertProps {
  /**
   * Current step name.
   */
  currentStep: string;
}

function VerifyFlowAlert({ currentStep }: VerifyFlowAlertProps) {
  let message;
  switch (currentStep) {
    case 'personal_key':
    case 'personal_key_confirm':
      message = t('idv.messages.confirm');
      break;

    default:
      return null;
  }

  return (
    <Alert type="success" className="margin-bottom-4">
      {message}
    </Alert>
  );
}

export default VerifyFlowAlert;
