import { PageHeading } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { getAssetPath } from '@18f/identity-assets';
import { HistoryLink } from '@18f/identity-form-steps';
import PasswordResetButton from './password-reset-button';

interface ForgotPasswordProps {
  stepPath: string;
}

export function ForgotPassword({ stepPath }: ForgotPasswordProps) {
  return (
    <>
      <img
        src={getAssetPath('status/info-question.svg')}
        width="54"
        height="54"
        alt={t('components.status_page.icons.question')}
        className="margin-bottom-4"
      />
      <PageHeading>{t('idv.forgot_password.modal_header')}</PageHeading>
      <ul className="usa-list">
        {t(['idv.forgot_password.warnings']).map((warning) => (
          <li key={warning}>{warning}</li>
        ))}
      </ul>
      <div className="margin-top-4">
        <HistoryLink basePath={stepPath} step={undefined} isVisualButton isBig isWide>
          {t('idv.forgot_password.try_again')}
        </HistoryLink>
      </div>
      <div className="margin-top-2">
        <PasswordResetButton />
      </div>
    </>
  );
}
