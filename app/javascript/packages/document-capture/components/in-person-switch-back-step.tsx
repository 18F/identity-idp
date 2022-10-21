import { useLayoutEffect } from 'react';
import { PageHeading } from '@18f/identity-components';
import { getAssetPath } from '@18f/identity-assets';
import { t } from '@18f/identity-i18n';
import type { FormStepComponentProps } from '@18f/identity-form-steps';

function InPersonSwitchBackStep({ onChange }: FormStepComponentProps<any>) {
  // Resetting the value prevents the user from being prompted about unsaved changes when closing
  // the tab. `useLayoutEffect` is used to avoid race conditions where the callback could occur at
  // the same time as the change handler's `ifStillMounted` wrapping `useEffect`, which would treat
  // it as unmounted and not update the value.
  useLayoutEffect(() => onChange({}, { patch: false }), []);

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.switch_back')}</PageHeading>
      <img
        src={getAssetPath('idv/switch.png')}
        width={193}
        alt={t('doc_auth.instructions.switch_back_image')}
      />
    </>
  );
}

export default InPersonSwitchBackStep;
