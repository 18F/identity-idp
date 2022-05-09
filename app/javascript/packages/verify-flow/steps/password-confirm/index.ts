import { t } from '@18f/identity-i18n';
import type { FormStep } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../../verify-flow';
import form from './password-confirm-step';
import submit from './submit';

export default {
  name: 'password_confirm',
  title: t('idv.titles.session.review'),
  form,
  submit,
} as FormStep<VerifyFlowValues>;
