import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

interface LocationCollectionItemProps {
  addressLine2: string;
  handleSelect: (event: React.FormEvent<HTMLInputElement>, selection: number) => void;
  name: string;
  saturdayHours: string;
  selectId: number;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

function LocationCollectionItem({
  addressLine2,
  handleSelect,
  name,
  saturdayHours,
  selectId,
  streetAddress,
  sundayHours,
  weekdayHours,
}: LocationCollectionItemProps) {
  const { t } = useI18n();

  return (
    <li className="location-collection-item">
      <div className="usa-collection__body">
        <div className="display-flex flex-justify">
          <h3 className="usa-collection__heading wrap-name">{name}</h3>
          <Button
            id="location_button"
            className="usa-button-mobile-hidden"
            onClick={(event) => {
              handleSelect(event, selectId);
            }}
            type="submit"
          >
            {t('in_person_proofing.body.location.location_button')}
          </Button>
        </div>
        <div>{streetAddress}</div>
        <div>{addressLine2}</div>
        <h4>{t('in_person_proofing.body.location.retail_hours_heading')}</h4>
        <div>{`${t('in_person_proofing.body.location.retail_hours_weekday')} ${weekdayHours}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sat')} ${saturdayHours}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sun')} ${sundayHours}`}</div>
        <Button
          id="location_button"
          className="usa-button-mobile usa-button-desktop-hidden"
          onClick={(event) => handleSelect(event, selectId)}
          type="submit"
        >
          {t('in_person_proofing.body.location.location_button')}
        </Button>
      </div>
    </li>
  );
}

export default LocationCollectionItem;
