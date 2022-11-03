import { TextInput, Button } from '@18f/identity-components';
import { useState, useEffect, useCallback, useRef, useContext } from 'react';

interface Location {
  street_address: string;
  city: string;
  state: string;
  zip_code: string;
}

interface AddressSearchProps {
  onAddressFound?: (location: Location) => void;
}

const ADDRESS_SEARCH_URL = '/verify/in_person/addresses';

function buildAddressSearchUrl(addressQuery) {
  return `${ADDRESS_SEARCH_URL}?address=${addressQuery}`;
}

function AddressSearch({ onAddressFound = () => {} }: AddressSearchProps) {
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  const handleAddressSearch = useCallback(async (e) => {
    try {
      const response = await fetch(buildAddressSearchUrl(unvalidatedAddressInput));
      const addressCandidates = await response.json();
      const [bestMatchedAddress] = addressCandidates;

      onAddressFound(bestMatchedAddress);
    } catch (e) {

    }

  }, [unvalidatedAddressInput]);

  return <>
    <TextInput
      value={unvalidatedAddressInput}
      onChange={(ev) => setUnvalidatedAddressInput(ev.target.value)}
      label="Search for an address"
    />
    <Button
      onClick={() => handleAddressSearch()}
    >Search</Button>
  </>;
}

export default AddressSearch;
