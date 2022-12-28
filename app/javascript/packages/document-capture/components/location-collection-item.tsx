import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

interface LocationCollectionItemProps {
  distance?: string;
  formattedCityStateZip: string;
  handleSelect: (event: React.FormEvent<HTMLInputElement>, selection: number) => void;
  name?: string;
  phone?: string;
  saturdayHours: string;
  selectId: number;
  streetAddress: string;
  sundayHours: string;
  tty?: string;
  weekdayHours: string;
}

function LocationCollectionItem({
  distance,
  formattedCityStateZip,
  handleSelect,
  name,
  phone,
  saturdayHours,
  selectId,
  streetAddress,
  sundayHours,
  tty,
  weekdayHours,
}: LocationCollectionItemProps) {
  const { t } = useI18n();
  const numericDistance = distance?.split(' ')[0];

  return (
    <li className="location-collection-item">
      <div className="usa-collection__body">
        <div className="display-flex flex-justify">
          {numericDistance && (
            <h3 className="usa-collection__heading">
              {t('in_person_proofing.body.location.distance', {
                count: parseFloat(numericDistance),
              })}
            </h3>
          )}
          {!distance && <h3 className="usa-collection__heading">{name}</h3>}
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
        {(weekdayHours || saturdayHours || sundayHours) && (
          <h4>{t('in_person_proofing.body.location.retail_hours_heading')}</h4>
        )}
        {weekdayHours && (
          <div>
            {`${t('in_person_proofing.body.location.retail_hours_weekday')} ${weekdayHours}`}
          </div>
        )}
        {saturdayHours && (
          <div>{`${t('in_person_proofing.body.location.retail_hours_sat')} ${saturdayHours}`}</div>
        )}
        {sundayHours && (
          <div>{`${t('in_person_proofing.body.location.retail_hours_sun')} ${sundayHours}`}</div>
        )}
        {(phone || tty) && (
          <div>
            <h4>{t('in_person_proofing.body.location.contact_info_heading')}</h4>
            <div>{`${t('in_person_proofing.body.location.phone')} ${phone}`}</div>
            <div>{`${t('in_person_proofing.body.location.tty')} ${tty}`}</div>
          </div>
        )}
        <Button
          id={`location_button_mobile_${selectId}`}
          className="tablet:display-none margin-top-2 width-full"
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
