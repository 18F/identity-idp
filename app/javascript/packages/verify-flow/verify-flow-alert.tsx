import { t } from '@18f/identity-i18n';
import { Alert } from '@18f/identity-components';

interface VerifyFlowAlertProps {
  /**
   * Current step name.
   */
  currentStep: string;
}

/**
 * Returns the status message to show for a given step, if applicable.
 *
 * @param stepName Step name.
 */
function getStepMessage(stepName: string): string | undefined {
  if (stepName === 'personal_key' || stepName === 'personal_key_confirm') {
    return t('idv.messages.confirm');
  }
}

function VerifyFlowAlert({ currentStep }: VerifyFlowAlertProps) {
  const message = getStepMessage(currentStep);
  if (!message) {
    return null;
  }

  return (
    <Alert type="success" className="margin-bottom-4">
      {message}
    </Alert>
  );
}

export default VerifyFlowAlert;
