import { t } from '@18f/identity-i18n';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';
import type { InPersonLocationsProps } from '../types';

export interface FormattedLocation {
  formattedCityStateZip: string;
  distance: string;
  id: number;
  name: string;
  saturdayHours: string;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

function InPersonLocations({
  locations,
  onSelect,
  address,
  noInPersonLocationsDisplay: NoInPersonLocationsDisplay,
  resultsHeaderComponent: HeaderComponent,
  resultsSectionHeading: ResultsSectionHeading,
  nds = false,
}: InPersonLocationsProps) {
  if (nds) {
    if (locations?.length === 0) {
      return <NoInPersonLocationsDisplay address={address} nds />;
    }

    return (
      <>
        {ResultsSectionHeading && <ResultsSectionHeading />}
        {/* Announced like the default results heading, but kept a real heading (role="status"
            on the heading itself would replace its heading role). */}
        <div role="status">
          <h2 className="card__title text-left">
            {t('in_person_proofing.body.location.po_search.results_description', {
              address,
              count: locations?.length,
            })}
          </h2>
        </div>
        {HeaderComponent && <HeaderComponent />}
        <div className="card card--elevated text-left">
          <ul className="add-list-reset">
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
                nds
              />
            ))}
          </ul>
        </div>
      </>
    );
  }

  if (locations?.length === 0) {
    return <NoInPersonLocationsDisplay address={address} />;
  }

  return (
    <>
      {ResultsSectionHeading && <ResultsSectionHeading />}
      <h3 role="status">
        {t('in_person_proofing.body.location.po_search.results_description', {
          address,
          count: locations?.length,
        })}
      </h3>
      {HeaderComponent && <HeaderComponent />}
      {onSelect && <p>{t('in_person_proofing.body.location.po_search.results_instructions')}</p>}
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
