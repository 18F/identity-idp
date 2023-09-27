import { ComponentType } from 'react';
import { t } from '@18f/identity-i18n';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';
import type { InPersonLocationsProps } from '../types';

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

function InPersonLocations({
  locations,
  onSelect,
  address,
  noInPersonLocationsDisplay: NoInPersonLocationsDisplay,
  resultsHeaderComponent: HeaderComponent,
}: InPersonLocationsProps) {
  const isPilot = locations?.some((l) => l.isPilot);

  if (locations?.length === 0) {
    return <NoInPersonLocationsDisplay address={address} />;
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
      {HeaderComponent && <HeaderComponent />}
      {onSelect && <p>{t('in_person_proofing.body.location.po_search.results_instructions')}</p>}
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
