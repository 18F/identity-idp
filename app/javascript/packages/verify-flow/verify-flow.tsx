import { useEffect, useState } from 'react';
import { FormSteps } from '@18f/identity-form-steps';
import { trackEvent } from '@18f/identity-analytics';
import { getConfigValue } from '@18f/identity-config';
import { useObjectMemo } from '@18f/identity-react-hooks';
import { STEPS } from './steps';
import VerifyFlowStepIndicator, { VerifyFlowPath } from './verify-flow-step-indicator';
import { useSyncedSecretValues } from './context/secrets-context';
import FlowContext from './context/flow-context';
import useInitialStepValidation from './hooks/use-initial-step-validation';
import {
  AddressVerificationMethod,
  AddressVerificationMethodContextProvider,
} from './context/address-verification-method-context';
import ErrorBoundary from './error-boundary';

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

  dob?: string;

  completionURL?: string;
}

export interface VerifyFlowProps {
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
   * URL to path for session cancel.
   */
  cancelURL?: string;

  /**
   * Initial value for address verification method.
   */
  initialAddressVerificationMethod?: AddressVerificationMethod;

  /**
   * Flow path to render for step indicator.
   */
  flowPath?: VerifyFlowPath;

  /**
   * Callback invoked after completing the form.
   */
  onComplete: (values: VerifyFlowValues) => void;
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
  cancelURL = '',
  initialAddressVerificationMethod,
  flowPath,
  onComplete,
}: VerifyFlowProps) {
  let steps = STEPS;
  if (enabledStepNames) {
    steps = steps.filter(({ name }) => enabledStepNames.includes(name));
  }

  const [syncedValues, setSyncedValues] = useSyncedSecretValues(initialValues);
  const [currentStep, setCurrentStep] = useState(steps[0].name);
  const [initialStep, setCompletedStep] = useInitialStepValidation(basePath, steps);
  const context = useObjectMemo({
    cancelURL,
    currentStep,
    basePath,
    onComplete,
  });
  useEffect(() => {
    logStepVisited(currentStep);
  }, [currentStep]);

  function onStepSubmit(stepName: string) {
    logStepSubmitted(stepName);
    setCompletedStep(stepName);
  }

  function onFormComplete(values: VerifyFlowValues) {
    setCompletedStep(null);
    onComplete(values);
  }

  return (
    <ErrorBoundary>
      <FlowContext.Provider value={context}>
        <AddressVerificationMethodContextProvider initialMethod={initialAddressVerificationMethod}>
          <VerifyFlowStepIndicator currentStep={currentStep} path={flowPath} />
          <FormSteps
            steps={steps}
            initialValues={syncedValues}
            initialStep={initialStep}
            promptOnNavigate={false}
            basePath={basePath}
            titleFormat={`%{step} - ${getConfigValue('appName')}`}
            onChange={setSyncedValues}
            onStepSubmit={onStepSubmit}
            onStepChange={setCurrentStep}
            onComplete={onFormComplete}
          />
        </AddressVerificationMethodContextProvider>
      </FlowContext.Provider>
    </ErrorBoundary>
  );
}

export default VerifyFlow;
