import { t } from '@18f/identity-i18n';
import type { FormStep } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../..';
import form from './personal-key-step';
import submit from './submit';

export default {
  name: 'personal_key',
  title: t('titles.idv.personal_key'),
  form,
  submit,
} as FormStep<VerifyFlowValues>;
