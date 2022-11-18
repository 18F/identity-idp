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
  const headers = { 'Content-Type': 'application/json' };
  const meta: HTMLMetaElement | null = document.querySelector('meta[name="csrf-token"]');
  const csrf = meta?.content;
  if (csrf) {
    headers['X-CSRF-Token'] = csrf;
  }
  const handleAddressSearch = useCallback(async (e) => {
    try {
      const response = await fetch(ADDRESS_SEARCH_URL, {
          method: 'POST',
          headers: headers,
          body: JSON.stringify({ address: unvalidatedAddressInput }),
      });

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
      onChange={(ev) => setUnvalidatedAddressInput(ev.target.value) }
      label="Search for an address"
    />
    <Button
      onClick={() => handleAddressSearch()}
    >Search</Button>
  </>;
}

export default AddressSearch;
