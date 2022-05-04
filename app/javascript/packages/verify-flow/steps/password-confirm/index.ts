import { t } from '@18f/identity-i18n';
import type { FormStep } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../..';
import form from './password-confirm-step';

export default {
  name: 'password_confirm',
  title: t('titles.idv.session.review'),
  form,
} as FormStep<VerifyFlowValues>;
