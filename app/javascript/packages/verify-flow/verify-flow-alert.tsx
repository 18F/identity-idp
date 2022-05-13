import type { ReactNode } from 'react';
import { t } from '@18f/identity-i18n';
import { formatHTML } from '@18f/identity-react-i18n';
import { Alert } from '@18f/identity-components';
import type { VerifyFlowValues } from './verify-flow';

interface VerifyFlowAlertProps {
  /**
   * Current step name.
   */
  currentStep: string;

  /**
   * Current flow values.
   */
  values?: Partial<VerifyFlowValues>;
}

/**
 * Returns the status message to show for a given step, if applicable.
 *
 * @param stepName Step name.
 * @param values Flow values.
 */
function getStepMessage(
  stepName: string,
  values: Partial<VerifyFlowValues>,
): ReactNode | undefined {
  if (stepName === 'password_confirm' && values.phone) {
    return formatHTML(
      t('idv.messages.review.info_verified_html', {
        phone_message: `<strong>${t('idv.messages.phone.phone_of_record')}</strong>`,
      }),
      { strong: 'strong' },
    );
  }

  if (stepName === 'personal_key' || stepName === 'personal_key_confirm') {
    return t('idv.messages.confirm');
  }
}

function VerifyFlowAlert({ currentStep, values = {} }: VerifyFlowAlertProps) {
  const message = getStepMessage(currentStep, values);
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
