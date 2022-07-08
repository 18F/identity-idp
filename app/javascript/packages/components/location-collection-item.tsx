import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

// TODO: create locationItemObject based on data returned by API, should be separate file, need to look at api to determine fields
interface LocationCollectionItemProps {
  header: string;
  addressLine1: string;
  addressLine2: string;
  hoursWD: string;
  hoursSat: string;
  hoursSun: string;
}

function LocationCollectionItem({
  header,
  addressLine1,
  addressLine2,
  hoursWD,
  hoursSat,
  hoursSun,
}: LocationCollectionItemProps) {
  const { t } = useI18n();
  return (
    <li className="location-collection-item">
      <div className="usa-collection__body">
        <div className="display-flex flex-justify">
          <h3 className="usa-collection__heading">{header}</h3>
          <Button>{t('in_person_proofing.body.location.location_button')}</Button>
        </div>
        <div>{addressLine1}</div>
        <div>{addressLine2}</div>
        <h4>{t('in_person_proofing.body.location.retail_hours_heading')}</h4>
        <div>{`${t('in_person_proofing.body.location.retail_hours_weekday')} ${hoursWD}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sat')} ${hoursSat}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sun')} ${hoursSun}`}</div>
      </div>
    </li>
  );
}

export default LocationCollectionItem;
