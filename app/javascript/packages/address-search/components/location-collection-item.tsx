import { SpinnerButton } from '@18f/identity-spinner-button';
import { useI18n } from '@18f/identity-react-i18n';

interface LocationCollectionItemProps {
  distance?: string;
  formattedCityStateZip: string;
  handleSelect?: (event: React.MouseEvent, selection: number) => void;
  name?: string;
  saturdayHours: string;
  selectId: number;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

function LocationCollectionItem({
  distance,
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
  const numericDistance = distance?.split(' ')[0];

  return (
    <li className="location-collection-item">
      <div className="usa-collection__body">
        <div className="grid-row">
          <div className="grid-col-fill">
            {numericDistance && (
              <h3 className="usa-collection__heading margin-bottom-1">
                {t('in_person_proofing.body.location.distance', {
                  count: parseFloat(numericDistance),
                })}
              </h3>
            )}
            {!distance && <h3 className="usa-collection__heading margin-bottom-1">{name}</h3>}
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
              <div>
                {`${t('in_person_proofing.body.location.retail_hours_sat')} ${saturdayHours}`}
              </div>
            )}
            {sundayHours && (
              <div>
                {`${t('in_person_proofing.body.location.retail_hours_sun')} ${sundayHours}`}
              </div>
            )}
            {handleSelect && (
              <SpinnerButton
                className="tablet:display-none margin-top-2 width-full"
                onClick={(event) => handleSelect(event, selectId)}
                type="submit"
              >
                {t('in_person_proofing.body.location.location_button')}
              </SpinnerButton>
            )}
          </div>
          <div className="grid-col-auto">
            {handleSelect && (
              <SpinnerButton
                className="display-none tablet:display-inline-block"
                onClick={(event) => {
                  handleSelect(event, selectId);
                }}
                type="submit"
              >
                {t('in_person_proofing.body.location.location_button')}
              </SpinnerButton>
            )}
          </div>
        </div>
      </div>
    </li>
  );
}

export default LocationCollectionItem;
