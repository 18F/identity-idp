import { TextInput, Button } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import { useState, useCallback, ChangeEvent, useRef, Ref } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import ValidatedField from '@18f/identity-validated-field/validated-field';

interface Location {
  street_address: string;
  city: string;
  state: string;
  zip_code: string;
  address: string;
}

interface AddressSearchProps {
  onAddressFound?: (location: Location) => void;
  registerField: (field: string) => Ref<HTMLInputElement>;
}

export const ADDRESS_SEARCH_URL = '/api/addresses';

function AddressSearch({ onAddressFound = () => {}, registerField }: AddressSearchProps) {
  const validatedFieldRef = useRef<HTMLFormElement | null>(null);
  const [noAddressFoundErrors, setNoAddressFoundErrors] = useState('');
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  const { t } = useI18n();

  const handleAddressSearch = useCallback(
    async (event) => {
      event.preventDefault();
      validatedFieldRef.current?.input?.setCustomValidity('custom validity message');
      validatedFieldRef.current?.reportValidity();
      if (unvalidatedAddressInput === '') {
        return;
      }
      const addressCandidates = await request<Location>(ADDRESS_SEARCH_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        json: { address: unvalidatedAddressInput },
      });
      if (addressCandidates.length === 0) {
        setNoAddressFoundErrors('ERROR, not a real address');
        validatedFieldRef.current?.setCustomValidity('ERROR, not a real address');
        validatedFieldRef.current?.reportValidity();
        return;
      }
      const bestMatchedAddress = addressCandidates[0];
      onAddressFound(bestMatchedAddress);
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
      <Button type="submit" className="margin-y-5" onClick={handleAddressSearch}>
        {t('in_person_proofing.body.location.po_search.search_button')}
      </Button>
    </>
  );
}

export default AddressSearch;
