import { useEffect } from 'react';
import { FormSteps } from '@18f/identity-form-steps';
import { StepIndicator, StepIndicatorStep, StepStatus } from '@18f/identity-step-indicator';
import { t } from '@18f/identity-i18n';
import { Alert } from '@18f/identity-components';
import { trackEvent } from '@18f/identity-analytics';
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
  useEffect(() => {
    logStepVisited(STEPS[0].name);
  }, []);

  let steps = STEPS;
  if (enabledStepNames) {
    steps = steps.filter(({ name }) => enabledStepNames.includes(name));
  }

  return (
    <>
      <StepIndicator className="margin-x-neg-2 margin-top-neg-4 tablet:margin-x-neg-6 tablet:margin-top-neg-4">
        <StepIndicatorStep title="Getting Started" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify your ID" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify your personal details" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify phone or address" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Secure your account" status={StepStatus.CURRENT} />
      </StepIndicator>
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
        onStepChange={logStepVisited}
        onComplete={onComplete}
      />
    </>
  );
}
