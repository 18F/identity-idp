import { useEffect } from 'react';
import { PageHeading } from '@18f/identity-components';
import { t } from '@18f/identity-i18n';
import { Button } from '@18f/identity-components';

interface ForgotPasswordProps {}

export function ForgotPassword({}: ForgotPasswordProps) {
  return (
    <>
      <PageHeading>{t('idv.forgot_password.modal_header')}</PageHeading>
      <ul className="usa-list">
        <li>{t('idv.forgot_password.warnings.warning_1')}</li>
        <li>{t('idv.forgot_password.warnings.warning_2')}</li>
      </ul>
      <p>
        <Button isBig isWide>
          Try again
        </Button>
      </p>
      <p>
        <Button isBig isOutline isWide>
          Reset password
        </Button>
      </p>
    </>
  );
}
