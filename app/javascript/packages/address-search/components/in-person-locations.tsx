import { t } from '@18f/identity-i18n';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';

export interface FormattedLocation {
  formattedCityStateZip: string;
  distance: string;
  id: number;
  name: string;
  saturdayHours: string;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
  isPilot: boolean;
}

interface InPersonLocationsProps {
  locations: FormattedLocation[] | null | undefined;
  onSelect;
  address: string;
}

function InPersonLocations({ locations, onSelect, address }: InPersonLocationsProps) {
  const isPilot = locations?.some((l) => l.isPilot);

  if (locations?.length === 0) {
    return (
      <>
        <h3 role="status">
          {t('in_person_proofing.body.location.po_search.none_found', { address })}
        </h3>
        <p>{t('in_person_proofing.body.location.po_search.none_found_tip')}</p>
      </>
    );
  }

  return (
    <>
      <h3 role="status">
        {!isPilot &&
          t('in_person_proofing.body.location.po_search.results_description', {
            address,
            count: locations?.length,
          })}
      </h3>
      <p>{t('in_person_proofing.body.location.po_search.results_instructions')}</p>
      <LocationCollection>
        {(locations || []).map((item, index) => (
          <LocationCollectionItem
            key={`${index}-${item.name}`}
            handleSelect={onSelect}
            distance={item.distance}
            streetAddress={item.streetAddress}
            selectId={item.id}
            formattedCityStateZip={item.formattedCityStateZip}
            weekdayHours={item.weekdayHours}
            saturdayHours={item.saturdayHours}
            sundayHours={item.sundayHours}
          />
        ))}
      </LocationCollection>
    </>
  );
}

export default InPersonLocations;
