import { PageHeading } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { Button } from '@18f/identity-components';
import { getAssetPath } from '@18f/identity-assets';

interface ForgotPasswordProps {
  goBack: () => void;
}

export function ForgotPassword({ goBack }: ForgotPasswordProps) {
  const stepIndicator = document.getElementsByTagName('lg-step-indicator')[0];
  hideStepIndicator();

  function goToResetPassword() {
    const resetPasswordUrl = `${window.location.origin}/forgot_password`;
    window.location.href = resetPasswordUrl;
  }

  function hideStepIndicator() {
    stepIndicator.hidden = true;
  }

  function showStepIndicator() {
    stepIndicator.hidden = false;
  }

  return (
    <>
      <img
        src={getAssetPath('status/info-question.svg')}
        width="50"
        height="50"
        className="margin-bottom-4"
      ></img>
      <PageHeading>{t('idv.forgot_password.modal_header')}</PageHeading>
      <ul className="usa-list">
        <li>{t('idv.forgot_password.warnings.warning_1')}</li>
        <li>{t('idv.forgot_password.warnings.warning_2')}</li>
      </ul>
      <p>
        <Button
          className="margin-top-4"
          isBig
          isWide
          onClick={() => {
            showStepIndicator();
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
