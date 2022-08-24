import { useContext } from 'react';
import { StepIndicator, StepIndicatorStep, StepStatus } from '@18f/identity-step-indicator';
import { t } from '@18f/identity-i18n';
import AddressVerificationMethodContext from './context/address-verification-method-context';
import type { AddressVerificationMethod } from './context/address-verification-method-context';

export enum VerifyFlowPath {
  DEFAULT = 'default',
  IN_PERSON = 'in_person',
}

type VerifyFlowStepIndicatorStep =
  | 'getting_started'
  | 'verify_id'
  | 'verify_info'
  | 'verify_phone_or_address'
  | 'secure_account'
  | 'find_a_post_office'
  | 'go_to_the_post_office';

interface VerifyFlowConfig {
  /**
   * Sequence of step indicator steps.
   */
  steps: VerifyFlowStepIndicatorStep[];

  /**
   * Mapping of flow form steps to corresponding step indicator step.
   */
  mapping: Record<string, VerifyFlowStepIndicatorStep>;
}

const FLOW_STEP_PATHS: Record<VerifyFlowPath, VerifyFlowConfig> = {
  [VerifyFlowPath.DEFAULT]: {
    steps: [
      'getting_started',
      'verify_id',
      'verify_info',
      'verify_phone_or_address',
      'secure_account',
    ],
    mapping: {
      document_capture: 'verify_id',
      password_confirm: 'secure_account',
      personal_key: 'secure_account',
      personal_key_confirm: 'secure_account',
    },
  },
  [VerifyFlowPath.IN_PERSON]: {
    steps: [
      'find_a_post_office',
      'verify_info',
      'verify_phone_or_address',
      'secure_account',
      'go_to_the_post_office',
    ],
    mapping: {
      document_capture: 'find_a_post_office',
    },
  },
};

interface VerifyFlowStepIndicatorProps {
  /**
   * Current flow path for the user.
   */
  path?: VerifyFlowPath;

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

/**
 * Given contextual details of the current flow path, returns explicit statuses which should be used
 * at particular steps.
 *
 * @param details Flow details
 *
 * @return Step status overrides.
 */
function getStatusOverrides({
  addressVerificationMethod,
}: {
  addressVerificationMethod: AddressVerificationMethod;
}) {
  const statuses: Partial<Record<VerifyFlowStepIndicatorStep, StepStatus>> = {};

  if (addressVerificationMethod === 'gpo') {
    statuses.verify_phone_or_address = StepStatus.PENDING;
  }

  return statuses;
}

function VerifyFlowStepIndicator({
  currentStep,
  path = VerifyFlowPath.DEFAULT,
}: VerifyFlowStepIndicatorProps) {
  const { steps, mapping } = FLOW_STEP_PATHS[path];
  const currentStepIndex = steps.indexOf(mapping[currentStep]);
  const { addressVerificationMethod } = useContext(AddressVerificationMethodContext);
  const statusOverrides = getStatusOverrides({ addressVerificationMethod });

  // i18n-tasks-use t('step_indicator.flows.idv.getting_started')
  // i18n-tasks-use t('step_indicator.flows.idv.verify_id')
  // i18n-tasks-use t('step_indicator.flows.idv.verify_info')
  // i18n-tasks-use t('step_indicator.flows.idv.verify_phone_or_address')
  // i18n-tasks-use t('step_indicator.flows.idv.secure_account')
  // i18n-tasks-use t('step_indicator.flows.idv.find_a_post_office')
  // i18n-tasks-use t('step_indicator.flows.idv.go_to_the_post_office')

  return (
    <StepIndicator className="margin-x-neg-2 margin-top-neg-4 tablet:margin-x-neg-6 tablet:margin-top-neg-4">
      {steps.map((step, index) => (
        <StepIndicatorStep
          key={step}
          title={t(`step_indicator.flows.idv.${step}`)}
          status={statusOverrides[step] || getStepStatus(index, currentStepIndex)}
        />
      ))}
    </StepIndicator>
  );
}

export default VerifyFlowStepIndicator;
