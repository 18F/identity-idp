import { useContext } from 'react';
import { PageHeading, Button } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { getAssetPath } from '@18f/identity-assets';
import { FormStepsContext } from '@18f/identity-form-steps';

interface ForgotPasswordProps {
  goBack: () => void;
}

export function ForgotPassword({ goBack }: ForgotPasswordProps) {
  const { resetPasswordUrl } = useContext(FormStepsContext);

  function goToResetPassword() {
    window.location.href = resetPasswordUrl!;
  }

  return (
    <>
      <img
        src={getAssetPath('status/info-question.svg')}
        width="50"
        alt=""
        height="50"
        className="margin-bottom-4"
      />
      <PageHeading>{t('idv.forgot_password.modal_header')}</PageHeading>
      <ul className="usa-list">
        {t('idv.forgot_password.warnings').map((warning) => (
          <li key={warning}>{warning}</li>
        ))}
      </ul>
      <p>
        <Button
          className="margin-top-4"
          isBig
          isWide
          onClick={() => {
            goBack();
          }}
        >
          {t('idv.forgot_password.try_again')}
        </Button>
      </p>
      <p>
        <Button isBig isOutline isWide onClick={() => goToResetPassword()}>
          {t('idv.forgot_password.reset_password')}
        </Button>
      </p>
    </>
  );
}
