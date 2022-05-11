import { StepIndicator, StepIndicatorStep, StepStatus } from '@18f/identity-step-indicator';
import { t } from '@18f/identity-i18n';

// i18n-tasks-use t('step_indicator.flows.idv.getting_started')
// i18n-tasks-use t('step_indicator.flows.idv.verify_id')
// i18n-tasks-use t('step_indicator.flows.idv.verify_info')
// i18n-tasks-use t('step_indicator.flows.idv.verify_phone_or_address')
// i18n-tasks-use t('step_indicator.flows.idv.secure_account')

type VerifyFlowStepIndicatorStep =
  | 'getting_started'
  | 'verify_id'
  | 'verify_info'
  | 'verify_phone_or_address'
  | 'secure_account';

/**
 * Mapping of flow form steps to corresponding step indicator step.
 */
const FLOW_STEP_STEP_MAPPING: Record<string, VerifyFlowStepIndicatorStep> = {
  password_confirm: 'secure_account',
  personal_key: 'secure_account',
  personal_key_confirm: 'secure_account',
};

/**
 * Sequence of step indicator steps.
 */
const STEP_INDICATOR_STEPS: VerifyFlowStepIndicatorStep[] = [
  'getting_started',
  'verify_id',
  'verify_info',
  'verify_phone_or_address',
  'secure_account',
];

interface VerifyFlowStepIndicatorProps {
  /**
   * Current step name.
   */
  currentStep: string;
}

/**
 * Given an index of a step and the current step index, returns the status of the step relative to
 * the current step.
 *
 * @param index Index of step against which to compare current step.
 * @param currentStepIndex Index of current step.
 *
 * @return Step status.
 */
export function getStepStatus(index, currentStepIndex): StepStatus {
  if (index === currentStepIndex) {
    return StepStatus.CURRENT;
  }

  if (index < currentStepIndex) {
    return StepStatus.COMPLETE;
  }

  return StepStatus.INCOMPLETE;
}

function VerifyFlowStepIndicator({ currentStep }: VerifyFlowStepIndicatorProps) {
  const currentStepIndex = STEP_INDICATOR_STEPS.indexOf(FLOW_STEP_STEP_MAPPING[currentStep]);

  return (
    <StepIndicator className="margin-x-neg-2 margin-top-neg-4 tablet:margin-x-neg-6 tablet:margin-top-neg-4">
      {STEP_INDICATOR_STEPS.map((step, index) => (
        <StepIndicatorStep
          key={step}
          title={t(`step_indicator.flows.idv.${step}`)}
          status={getStepStatus(index, currentStepIndex)}
        />
      ))}
    </StepIndicator>
  );
}

export default VerifyFlowStepIndicator;
