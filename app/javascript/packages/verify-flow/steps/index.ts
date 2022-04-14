import type { FormStep } from '@18f/identity-form-steps';
import PersonalKeyStep from './personal-key/personal-key-step';

export const STEPS: FormStep[] = [
  {
    name: 'personal-key',
    form: PersonalKeyStep,
  },
];
