import { SpinnerButton } from '@18f/identity-spinner-button';
import { t } from '@18f/identity-i18n';

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
  nds?: boolean;
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
  nds = false,
}: LocationCollectionItemProps) {
  const numericDistance = distance?.split(' ')[0];

  if (nds) {
    // Figma puts Select beside the distance from tablet up and full width below the hours on
    // mobile; the wrappers hide the other placement entirely, including its spinner element.
    const selectButton = (wrapperClassName: string, buttonClassName?: string) =>
      handleSelect && (
        <div className={wrapperClassName}>
          <SpinnerButton
            className={['usa-button--md', buttonClassName].filter(Boolean).join(' ')}
            onClick={(event) => handleSelect(event, selectId)}
            type="submit"
          >
            {t('in_person_proofing.body.location.location_button')}
          </SpinnerButton>
        </div>
      );

    return (
      <li className="location-collection__item">
        <div className="location-collection__top">
          <div className="location-collection__details">
            <h3 className="location-collection__distance">
              {numericDistance
                ? t('in_person_proofing.body.location.distance', {
                    count: parseFloat(numericDistance),
                  })
                : name}
            </h3>
            <p className="location-collection__address">
              {streetAddress}
              <br />
              {formattedCityStateZip}
            </p>
          </div>
          {selectButton('display-none tablet:display-block')}
        </div>
        {(weekdayHours || saturdayHours || sundayHours) && (
          <div className="location-collection__hours">
            <h4 className="text-body-emphasis margin-0">{t('nds.post_office.search.hours')}</h4>
            {weekdayHours && (
              <div>
                {`${t('in_person_proofing.body.location.retail_hours_weekday')} ${weekdayHours}`}
              </div>
            )}
            {saturdayHours && (
              <div>{`${t('nds.post_office.search.saturday')} ${saturdayHours}`}</div>
            )}
            {sundayHours && <div>{`${t('nds.post_office.search.sunday')} ${sundayHours}`}</div>}
          </div>
        )}
        {selectButton('tablet:display-none', 'width-full')}
      </li>
    );
  }

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
