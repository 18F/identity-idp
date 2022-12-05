import { TextInput, Button } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import { useState, useCallback, ChangeEvent } from 'react';
import { useI18n } from '@18f/identity-react-i18n';

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
  const { t } = useI18n();
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
        label={t('in_person_proofing.body.location.address_search_label')}
      />
      <Button onClick={handleAddressSearch}>
        {t('in_person_proofing.body.location.search_button')}
      </Button>
      <>{addressQuery.address}</>
    </>
  );
}

export default AddressSearch;
