import { TextInput } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import { useState, useCallback, ChangeEvent, useRef, useEffect } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import ValidatedField from '@18f/identity-validated-field/validated-field';
import SpinnerButton, { SpinnerButtonRefHandle } from '@18f/identity-spinner-button/spinner-button';
import type { RegisterFieldCallback } from '@18f/identity-form-steps';
import useSWR from 'swr';

interface Location {
  street_address: string;
  city: string;
  state: string;
  zip_code: string;
  address: string;
}

interface AddressSearchProps {
  onAddressFound?: (location: Location) => void;
  registerField?: RegisterFieldCallback;
}

export const ADDRESS_SEARCH_URL = '/api/addresses';

function AddressSearch({
  registerField = () => undefined,
  onSearch = () => {},
  onAddressChanged = () => {},
  unvalidatedAddressInput = '',
  validatedFieldRef = null,
  loading = false,
}: AddressSearchProps) {
  const { t } = useI18n();
  const ref = useRef<SpinnerButtonRefHandle>(null);

  useEffect(() => {
    ref.current?.toggleSpinner(loading);
  }, [loading]);

  return (
    <>
      <ValidatedField
        ref={validatedFieldRef}
        messages={{
          valueMissing: t('in_person_proofing.body.location.inline_error'),
        }}
      >
        <TextInput
          required
          ref={registerField('address')}
          value={unvalidatedAddressInput}
          onChange={onAddressChanged}
          label={t('in_person_proofing.body.location.po_search.address_search_label')}
          hint={t('in_person_proofing.body.location.po_search.address_search_hint')}
        />
      </ValidatedField>
      <SpinnerButton isWide isBig ref={ref} type="submit" className="margin-y-5" onClick={onSearch}>
        {t('in_person_proofing.body.location.po_search.search_button')}
      </SpinnerButton>
    </>
  );
}

export default AddressSearch;
