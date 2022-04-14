import { FormSteps } from '@18f/identity-form-steps';
import { STEPS } from './steps';

export interface VerifyFlowValues {
  personalKey?: string;
}

interface VerifyFlowProps {
  initialValues?: Partial<VerifyFlowValues>;
}

export function VerifyFlow({ initialValues = {} }: VerifyFlowProps) {
  return <FormSteps steps={STEPS} initialValues={initialValues} />;
}
