import { useContext } from 'react';
import { PageHeading, Button } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { getAssetPath } from '@18f/identity-assets';
import { FlowContext } from '@18f/identity-verify-flow';

interface ForgotPasswordProps {
  goBack: () => void;
}

export function ForgotPassword({ goBack }: ForgotPasswordProps) {
  const { resetPasswordUrl } = useContext(FlowContext);

  function goToResetPassword() {
    window.location.href = resetPasswordUrl!;
  }

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
        {(t('idv.forgot_password.warnings') as unknown as string[]).map((warning) => (
          <li key={warning}>{warning}</li>
        ))}
      </ul>
      <div className="margin-top-4">
        <Button isBig isWide onClick={goBack}>
          {t('idv.forgot_password.try_again')}
        </Button>
      </div>
      <div className="margin-top-2">
        <Button isBig isOutline isWide onClick={goToResetPassword}>
          {t('idv.forgot_password.reset_password')}
        </Button>
      </div>
    </>
  );
}
