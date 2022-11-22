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

function toFormData(object: Record<string, any>): FormData {
  return Object.keys(object).reduce((form, key) => {
    const value = object[key];
    if (value !== undefined) {
      form.append(key, value);
    }

    return form;
  }, new window.FormData());
}

const ADDRESS_SEARCH_URL = '/api/addresses';

function AddressSearch({ onAddressFound = () => {} }: AddressSearchProps) {
  const [unvalidatedAddressInput, setUnvalidatedAddressInput] = useState('');
  const handleAddressSearch = useCallback(async (e) => {
    try {
      const response = await fetch(ADDRESS_SEARCH_URL, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ address: '120 broadway' }),
      });
      // console.log(await response.json())
      const addressCandidates = await response.json();
      const [bestMatchedAddress] = addressCandidates;

      onAddressFound(bestMatchedAddress);
    } catch (e) {
      console.log(e);
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
