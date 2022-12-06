import { TextInput, Button } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import { useState, useCallback, ChangeEvent } from 'react';
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
}

export const ADDRESS_SEARCH_URL = '/api/addresses';

function AddressSearch({ onAddressFound = () => {} }: AddressSearchProps) {
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  const [addressQuery, setAddressQuery] = useState({} as Location);

  const handleAddressSearch = useCallback(async () => {
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
  }, [unvalidatedAddressInput]);

  return (
    <>
      <ValidatedField>
        <TextInput
          required
          value={unvalidatedAddressInput}
          onChange={(event: ChangeEvent) => {
            const target = event.target as HTMLInputElement;
            setUnvalidatedAddressInput(target.value);
          }}
          label="Search for an address"
        />
      </ValidatedField>
      <Button onClick={() => handleAddressSearch()}>Search</Button>
      <>{addressQuery.address}</>
    </>
  );
}

export default AddressSearch;
