import type { FormStep } from '@18f/identity-form-steps';
import { t } from '@18f/identity-i18n';
import PersonalKeyStep from './personal-key/personal-key-step';
import PersonalKeyConfirmStep from './personal-key-confirm/personal-key-confirm-step';

export const STEPS: FormStep[] = [
  {
    name: 'personal_key',
    form: PersonalKeyStep,
    title: t('titles.idv.personal_key'),
  },
  {
    name: 'personal_key_confirm',
    form: PersonalKeyConfirmStep,
    title: t('titles.idv.personal_key'),
  },
];
