import type { FormStep } from '@18f/identity-form-steps';
import { t } from '@18f/identity-i18n';
import PersonalKeyStep from './personal-key/personal-key-step';
import PersonalKeyConfirmStep from './personal-key-confirm/personal-key-confirm-step';
import PasswordConfirmStep from './password-confirm/password-confirm-step';

export const STEPS: FormStep[] = [
  {
    name: 'password-confirm',
    form:  PasswordConfirmStep,
    title: t('titles.idv.session.review'),
  },
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
