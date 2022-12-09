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
}

function InPersonLocations({ locations, didSelect }: InPersonLocationsProps) {
  const { t } = useI18n();

  if (locations?.length === 0) {
    return <h4>{t('in_person_proofing.body.location.none_found')}</h4>;
  }

  return (
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
  );
}

export default InPersonLocations;
