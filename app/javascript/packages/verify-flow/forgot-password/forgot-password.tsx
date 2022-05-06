import { PageHeading } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { Button } from '@18f/identity-components';

interface ForgotPasswordProps {
  goBack: () => void;
}

export function ForgotPassword({ goBack }: ForgotPasswordProps) {
  function goToResetPassword() {
    const resetPasswordUrl = `${window.location.origin}/forgot_password`;
    console.log(resetPasswordUrl);
    window.location.href = resetPasswordUrl;
  }

  return (
    <>
      <PageHeading>{t('idv.forgot_password.modal_header')}</PageHeading>
      <ul className="usa-list">
        <li>{t('idv.forgot_password.warnings.warning_1')}</li>
        <li>{t('idv.forgot_password.warnings.warning_2')}</li>
      </ul>
      <p>
        <Button
          isBig
          isWide
          onClick={() => {
            goBack();
          }}
        >
          Try again
        </Button>
      </p>
      <p>
        <Button isBig isOutline isWide onClick={() => goToResetPassword()}>
          Reset password
        </Button>
      </p>
    </>
  );
}
