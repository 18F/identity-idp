import { TextInput, Button } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import { useState, useCallback, ChangeEvent } from 'react';

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
    const addressCandidates = await request(ADDRESS_SEARCH_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      json: { address: unvalidatedAddressInput },
    });

    const bestMatchedAddress = addressCandidates[0];
    setAddressQuery(bestMatchedAddress);
    onAddressFound(bestMatchedAddress);
  }, [unvalidatedAddressInput]);

  return (
    <>
      <TextInput
        value={unvalidatedAddressInput}
        onChange={(event: ChangeEvent) => {
          const target = event.target as HTMLInputElement;

          setUnvalidatedAddressInput(target.value);
        }}
        label="Search for an address"
      />
      <Button onClick={handleAddressSearch}>Search</Button>
      <>{addressQuery.address}</>
    </>
  );
}

export default AddressSearch;
