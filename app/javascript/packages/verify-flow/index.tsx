import { FormSteps } from '@18f/identity-form-steps';
import { STEPS } from './steps';

export function VerifyFlow() {
  return <FormSteps steps={STEPS} />;
}
