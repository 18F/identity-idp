import { TextInput, Button } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import { useState, useCallback, ChangeEvent, useRef } from 'react';
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
  registerField: () => {};
}

export const ADDRESS_SEARCH_URL = '/api/addresses';

function AddressSearch({ onAddressFound = () => {}, registerField }: AddressSearchProps) {
  const validatedFieldRef = useRef();
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  const [addressQuery, setAddressQuery] = useState({} as Location);

  const handleAddressSearch = useCallback(
    async (event) => {
      event.preventDefault();
      validatedFieldRef.current.reportValidity();
      if (unvalidatedAddressInput === '') {
        return null;
      }
      const addressCandidates = await request(ADDRESS_SEARCH_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        json: { address: unvalidatedAddressInput },
      });

      const [bestMatchedAddress] = addressCandidates;
      setAddressQuery(bestMatchedAddress);
      onAddressFound(bestMatchedAddress);
    },
    [unvalidatedAddressInput],
  );

  return (
    <>
      <ValidatedField
        ref={validatedFieldRef}
        messages={{ valueMissing: 'Include a city, state, and ZIP code' }}
      >
        <TextInput
          required
          ref={registerField('address')}
          value={unvalidatedAddressInput}
          onChange={(event: ChangeEvent) => {
            const target = event.target as HTMLInputElement;
            setUnvalidatedAddressInput(target.value);
          }}
          label="Search for an address"
        />
      </ValidatedField>
      <Button type="submit" onClick={handleAddressSearch}>
        Search
      </Button>
      <>{addressQuery.address}</>
    </>
  );
}

export default AddressSearch;
