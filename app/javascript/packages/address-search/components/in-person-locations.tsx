import { t } from '@18f/identity-i18n';
import InPersonLocationRedirectAlert from './in-person-location-redirect-alert';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';
import NoInPersonLocationsDisplay from './no-in-person-locations-display';

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
  infoAlertURL?: string;
}

function InPersonLocations({ locations, onSelect, address, infoAlertURL }: InPersonLocationsProps) {
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
      {infoAlertURL && <InPersonLocationRedirectAlert infoAlertURL={infoAlertURL} />}
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
