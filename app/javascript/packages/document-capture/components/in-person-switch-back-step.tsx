import { useEffect } from 'react';
import { PageHeading } from '@18f/identity-components';
import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';

function InPersonSwitchBackStep({ onChange }: FormStepComponentProps<any>) {
  useEffect(() => onChange({}, { patch: false }), []);

  return (
    <>
      <PageHeading>{t('doc_auth.instructions.switch_back')}</PageHeading>
      <img
        src={getAssetPath('idv/switch.png')}
        width={193}
        alt={t('doc_auth.instructions.switch_back_image')}
      />
    </>
  );
}

export default InPersonSwitchBackStep;
