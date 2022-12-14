import { useI18n } from '@18f/identity-react-i18n';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';

export interface FormattedLocation {
  formattedCityStateZip: string;
  id: number;
  name: string;
  phone: string;
  saturdayHours: string;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

interface InPersonLocationsProps {
  locations: FormattedLocation[] | null | undefined;
  didSelect;
  address: string;
}

function InPersonLocations({ locations, didSelect, address }: InPersonLocationsProps) {
  const { t } = useI18n();

  if (locations?.length === 0) {
    return (
      <>
        <h3>{t('in_person_proofing.body.location.po_search.none_found', { address })}</h3>
        <p>{t('in_person_proofing.body.location.po_search.none_found_tip')}</p>
      </>
    );
  }

  return (
    <>
      <h3>
        {t('in_person_proofing.body.location.po_search.results_description', {
          address,
          count: locations?.length,
        })}
      </h3>
      <p>{t('in_person_proofing.body.location.po_search.results_instructions')}</p>
      <LocationCollection>
        {(locations || []).map((item, index) => (
          <LocationCollectionItem
            key={`${index}-${item.name}`}
            handleSelect={didSelect}
            name={`${item.name} — ${t('in_person_proofing.body.location.post_office')}`}
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
