import { lazy } from 'react';
import { t } from '@18f/identity-i18n';
import { getConfigValue } from '@18f/identity-config';
import type { FormStep } from '@18f/identity-form-steps';
import type { VerifyFlowValues } from '../../verify-flow';
import submit from './submit';

const load = () =>
  import(/* webpackChunkName: "verify-flow-password-confirm" */ './password-confirm-step');

export default {
  name: 'password_confirm',
  title: t('idv.titles.session.review', { app_name: getConfigValue('appName') }),
  form: lazy(load),
  submit,
  preload: load,
} as FormStep<VerifyFlowValues>;
