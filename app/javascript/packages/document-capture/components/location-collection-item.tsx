import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

interface LocationCollectionItemProps {
  formattedCityStateZip: string;
  handleSelect: (event: React.FormEvent<HTMLInputElement>, selection: number) => void;
  name: string;
  saturdayHours: string;
  selectId: number;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

function LocationCollectionItem({
  formattedCityStateZip,
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
          <h3 className="usa-collection__heading">{name}</h3>
          <Button
            id={`location_button_desktop_${selectId}`}
            className="display-none tablet:display-inline-block"
            onClick={(event) => {
              handleSelect(event, selectId);
            }}
            type="submit"
          >
            {t('in_person_proofing.body.location.location_button')}
          </Button>
        </div>
        <div>{streetAddress}</div>
        <div>{formattedCityStateZip}</div>
        <h4>{t('in_person_proofing.body.location.retail_hours_heading')}</h4>
        <div>{`${t('in_person_proofing.body.location.retail_hours_weekday')} ${weekdayHours}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sat')} ${saturdayHours}`}</div>
        <div>{`${t('in_person_proofing.body.location.retail_hours_sun')} ${sundayHours}`}</div>
        <Button
          id={`location_button_mobile_${selectId}`}
          className="tablet:display-none margin-top-2"
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
