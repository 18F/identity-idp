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

function requestAddressCandidates(unvalidatedAddressInput: string): Promise<Location[]> {
  return request<Location[]>(ADDRESS_SEARCH_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    json: { address: unvalidatedAddressInput },
  });
}

function AddressSearch({
  onAddressFound = () => {},
  registerField = () => undefined,
}: AddressSearchProps) {
  const validatedFieldRef = useRef<HTMLFormElement | null>(null);
  const [noAddressFoundErrors, setNoAddressFoundErrors] = useState('');
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  const [addressQuery, setAddressQuery] = useState('');
  const { t } = useI18n();
  const { data: addressCandidates } = useSWR([ADDRESS_SEARCH_URL, addressQuery], () =>
    addressQuery ? requestAddressCandidates(unvalidatedAddressInput) : null,
  );
  const ref = useRef<SpinnerButtonRefHandle>(null);

  useEffect(() => {
    if (addressCandidates) {
      const bestMatchedAddress = addressCandidates[0];
      onAddressFound(bestMatchedAddress);
      ref.current?.toggleSpinner(false);
    }
    if (addressCandidates?.length === 0) {
      setNoAddressFoundErrors('ERROR, not a real address');
      validatedFieldRef.current?.setCustomValidity('ERROR, not a real address');
      validatedFieldRef.current?.reportValidity();
    }
  }, [addressCandidates]);

  const handleAddressSearch = useCallback(
    (event) => {
      event.preventDefault();
      validatedFieldRef.current?.reportValidity();
      if (unvalidatedAddressInput === '') {
        return;
      }
      setAddressQuery(unvalidatedAddressInput);
    },
    [unvalidatedAddressInput],
  );

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
          onChange={(event: ChangeEvent) => {
            const target = event.target as HTMLInputElement;
            setUnvalidatedAddressInput(target.value);
          }}
          label={t('in_person_proofing.body.location.po_search.address_search_label')}
          hint={t('in_person_proofing.body.location.po_search.address_search_hint')}
        />
      </ValidatedField>
      <SpinnerButton
        isWide
        isBig
        ref={ref}
        type="submit"
        className="margin-y-5"
        onClick={handleAddressSearch}
      >
        {t('in_person_proofing.body.location.po_search.search_button')}
      </SpinnerButton>
    </>
  );
}

export default AddressSearch;
