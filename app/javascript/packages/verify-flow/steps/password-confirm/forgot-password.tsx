import { StatusPage } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { HistoryLink } from '@18f/identity-form-steps';
import PasswordResetButton from './password-reset-button';

interface ForgotPasswordProps {
  stepPath: string;
}

export function ForgotPassword({ stepPath }: ForgotPasswordProps) {
  return (
    <StatusPage
      status="info"
      icon="question"
      header={t('idv.forgot_password.modal_header')}
      actionButtons={[
        <HistoryLink
          key="try_again"
          basePath={stepPath}
          step={undefined}
          isVisualButton
          isBig
          isWide
        >
          {t('idv.forgot_password.try_again')}
        </HistoryLink>,
        <PasswordResetButton key="password_reset" />,
      ]}
    >
      <ul className="usa-list">
        {t(['idv.forgot_password.warnings']).map((warning) => (
          <li key={warning}>{warning}</li>
        ))}
      </ul>
    </StatusPage>
  );
}
