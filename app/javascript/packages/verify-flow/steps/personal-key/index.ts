import { t } from '@18f/identity-i18n';
import type { FormStep } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../../verify-flow';
import form from './personal-key-step';

export default {
  name: 'personal_key',
  title: t('titles.idv.personal_key'),
  form,
} as FormStep<VerifyFlowValues>;
