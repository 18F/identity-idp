import type { FormStep } from '@18f/identity-form-steps';
import PersonalKeyStep from './personal-key/personal-key-step';
import PersonalKeyConfirmStep from './personal-key-confirm/personal-key-confirm-step';

export const STEPS: FormStep[] = [
  {
    name: 'personal_key',
    form: PersonalKeyStep,
  },
  {
    name: 'personal_key_confirm',
    form: PersonalKeyConfirmStep,
  },
];
