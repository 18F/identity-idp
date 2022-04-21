import { FormSteps } from '@18f/identity-form-steps';
import { StepIndicator, StepIndicatorStep, StepStatus } from '@18f/identity-step-indicator';
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
   * The path to which the current step is appended to create the current step URL.
   */
  basePath: string;

  /**
   * Application name, used in generating page titles for current step.
   */
  appName: string;
}

export function VerifyFlow({ initialValues = {}, basePath, appName }: VerifyFlowProps) {
  return (
    <>
      <StepIndicator className="margin-x-neg-2 margin-top-neg-4 tablet:margin-x-neg-6 tablet:margin-top-neg-4">
        <StepIndicatorStep title="Getting Started" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify your ID" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify your personal details" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify phone or address" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Secure your account" status={StepStatus.CURRENT} />
      </StepIndicator>
      <FormSteps
        steps={STEPS}
        initialValues={initialValues}
        promptOnNavigate={false}
        basePath={basePath}
        titleFormat={`%{step} - ${appName}`}
      />
    </>
  );
}
