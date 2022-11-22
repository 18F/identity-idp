import { TextInput, Button } from '@18f/identity-components';
import { useState, useCallback } from 'react';

interface Location {
  street_address: string;
  city: string;
  state: string;
  zip_code: string;
}

interface AddressSearchProps {
  onAddressFound?: (location: Location) => void;
  request: Function;
}

const ADDRESS_SEARCH_URL = '/api/addresses';

function AddressSearch({ onAddressFound = () => {}, request }: AddressSearchProps) {
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  const handleAddressSearch = useCallback(async () => {
    const addressCandidates = await request(
      ADDRESS_SEARCH_URL,
      { address: '120 broadway' },
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
      },
    );

    const [bestMatchedAddress] = addressCandidates;

    onAddressFound(bestMatchedAddress);
  }, [unvalidatedAddressInput]);

  return (
    <>
      <TextInput
        value={unvalidatedAddressInput}
        onChange={(ev) => setUnvalidatedAddressInput(ev.target.value)}
        label="Search for an address"
      />
      <Button onClick={() => handleAddressSearch()}>Search</Button>
    </>
  );
}

export default AddressSearch;
