import { FormSteps } from '@18f/identity-form-steps';
import { StepIndicator, StepIndicatorStep, StepStatus } from '@18f/identity-step-indicator';
import { STEPS } from './steps';

export interface VerifyFlowValues {
  personalKey?: string;
}

interface VerifyFlowProps {
  initialValues?: Partial<VerifyFlowValues>;
}

export function VerifyFlow({ initialValues = {} }: VerifyFlowProps) {
  return (
    <>
      <StepIndicator className="margin-x-neg-2 margin-top-neg-4 tablet:margin-x-neg-6 tablet:margin-top-neg-4">
        <StepIndicatorStep title="Getting Started" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify your ID" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify your personal details" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Verify phone or address" status={StepStatus.COMPLETE} />
        <StepIndicatorStep title="Secure your account" status={StepStatus.CURRENT} />
      </StepIndicator>
      <FormSteps steps={STEPS} initialValues={initialValues} promptOnNavigate={false} />
    </>
  );
}
