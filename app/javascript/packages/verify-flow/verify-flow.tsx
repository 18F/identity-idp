import { useEffect, useState } from 'react';
import { FormSteps } from '@18f/identity-form-steps';
import { trackEvent } from '@18f/identity-analytics';
import { STEPS } from './steps';
import VerifyFlowStepIndicator from './verify-flow-step-indicator';
import VerifyFlowAlert from './verify-flow-alert';
import { useSyncedSecretValues } from './context/secrets-context';
import useInitialStepValidation from './hooks/use-initial-step-validation';

export interface VerifyFlowValues {
  userBundleToken?: string;

  personalKey?: string;

  personalKeyConfirm?: string;

  firstName?: string;

  lastName?: string;

  address1?: string;

  address2?: string;

  city?: string;

  state?: string;

  zipcode?: string;

  phone?: string;

  ssn?: string;

  password?: string;
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
  basePath: string;

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

function VerifyFlow({
  initialValues = {},
  enabledStepNames,
  basePath,
  appName,
  onComplete,
}: VerifyFlowProps) {
  let steps = STEPS;
  if (enabledStepNames) {
    steps = steps.filter(({ name }) => enabledStepNames.includes(name));
  }

  const [syncedValues, setSyncedValues] = useSyncedSecretValues(initialValues);
  const [currentStep, setCurrentStep] = useState(steps[0].name);
  const [initialStep, setCompletedStep] = useInitialStepValidation(basePath, steps);
  useEffect(() => {
    logStepVisited(currentStep);
  }, [currentStep]);

  function onStepSubmit(stepName: string) {
    logStepSubmitted(stepName);
    setCompletedStep(stepName);
  }

  return (
    <>
      <VerifyFlowStepIndicator currentStep={currentStep} />
      <VerifyFlowAlert currentStep={currentStep} />
      <FormSteps
        steps={steps}
        initialValues={syncedValues}
        initialStep={initialStep}
        promptOnNavigate={false}
        basePath={basePath}
        titleFormat={`%{step} - ${appName}`}
        onChange={setSyncedValues}
        onStepSubmit={onStepSubmit}
        onStepChange={setCurrentStep}
        onComplete={onComplete}
      />
    </>
  );
}

export default VerifyFlow;
