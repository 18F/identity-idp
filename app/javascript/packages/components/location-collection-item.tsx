import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

interface LocationCollectionItemProps {
  name: string;
  streetAddress: string;
  addressLine2: string;
  weekdayHours: string;
  saturdayHours: string;
  sundayHours: string;
}

function LocationCollectionItem({
  name,
  streetAddress,
  addressLine2,
  weekdayHours,
  saturdayHours,
  sundayHours,
}: LocationCollectionItemProps) {
  const { t } = useI18n();
  return (
    <li className="location-collection-item">
      <div className="usa-collection__body">
        <div className="display-flex flex-justify">
          <h3 className="usa-collection__heading">{name}</h3>
          <Button>{t('in_person_proofing.body.location.location_button')}</Button>
        </div>
        <div>{streetAddress}</div>
        <div>{addressLine2}</div>
        <h4>{t('in_person_proofing.body.location.retail_hours_heading')}</h4>
        <div>{`${t('in_person_proofing.body.location.retail_hours_weekday')} ${weekdayHours}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sat')} ${saturdayHours}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sun')} ${sundayHours}`}</div>
      </div>
    </li>
  );
}

export default LocationCollectionItem;
