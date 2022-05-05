import { useEffect, useState } from 'react';
import { FormSteps } from '@18f/identity-form-steps';
import { t } from '@18f/identity-i18n';
import { Alert } from '@18f/identity-components';
import { trackEvent } from '@18f/identity-analytics';
import VerifyFlowStepIndicator from './verify-flow-step-indicator';
import { STEPS } from './steps';

export interface VerifyFlowValues {
  personalKey?: string;

  personalKeyConfirm?: string;
}

interface VerifyFlowProps {
  /**
   * Initial values for the form, if applicable.
   */
  initialValues?: Partial<VerifyFlowValues>;

  /**
   * Names of steps to be included in the flow.
   */
  enabledStepNames?: string[];

  /**
   * The path to which the current step is appended to create the current step URL.
   */
  basePath?: string;

  /**
   * Application name, used in generating page titles for current step.
   */
  appName: string;

  /**
   * Callback invoked after completing the form.
   */
  onComplete: () => void;
}

/**
 * Returns a step name normalized for event logging.
 *
 * @param stepName Original step name.
 *
 * @return Step name normalized for event logging.
 */
const getEventStepName = (stepName: string) => stepName.toLowerCase().replace(/[^a-z]/g, ' ');

/**
 * Logs step visited event.
 */
const logStepVisited = (stepName: string) =>
  trackEvent(`IdV: ${getEventStepName(stepName)} visited`);

/**
 * Logs step submitted event.
 */
const logStepSubmitted = (stepName: string) =>
  trackEvent(`IdV: ${getEventStepName(stepName)} submitted`);

export function VerifyFlow({
  initialValues = {},
  enabledStepNames,
  basePath,
  appName,
  onComplete,
}: VerifyFlowProps) {
  const [currentStep, setCurrentStep] = useState(STEPS[0].name);

  useEffect(() => {
    logStepVisited(currentStep);
  }, [currentStep]);

  let steps = STEPS;
  if (enabledStepNames) {
    steps = steps.filter(({ name }) => enabledStepNames.includes(name));
  }

  return (
    <>
      <VerifyFlowStepIndicator currentStep={currentStep} />
      <Alert type="success" className="margin-bottom-4">
        {t('idv.messages.confirm')}
      </Alert>
      <FormSteps
        steps={steps}
        initialValues={initialValues}
        promptOnNavigate={false}
        basePath={basePath}
        titleFormat={`%{step} - ${appName}`}
        onStepSubmit={logStepSubmitted}
        onStepChange={setCurrentStep}
        onComplete={onComplete}
      />
    </>
  );
}
