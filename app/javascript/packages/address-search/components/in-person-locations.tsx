import { useI18n } from '@18f/identity-react-i18n';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';
import { getAssetPath } from '@18f/identity-assets';
import type { ReactNode } from 'react';

export interface FormattedLocation {
  formattedCityStateZip: string;
  distance: string;
  id: number;
  name: string;
  saturdayHours: string;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
  isPilot: boolean;
}

interface InPersonLocationsProps {
  locations: FormattedLocation[] | null | undefined;
  onSelect;
  address: string;
  NoResultsHelpCenterMessage?: ReactNode
}

function InPersonLocations({ locations, onSelect, address, NoResultsHelpCenterMessage }: InPersonLocationsProps) {
  const { t } = useI18n();
  const isPilot = locations?.some((l) => l.isPilot);

  if (locations?.length === 0) {
    return (
      <>
        <NoResultsHelpCenterMessage address={address} />

        {/* { helpCenterDisplay &&
          <div className="grid-col-12 inline-block" style={{display: "inline-block"}}>
            <h3 role="status">
              {t('in_person_proofing.body.location.po_search.none_found', { address })}
            </h3>
        </div>
        } */}

        { !NoResultsHelpCenterMessage && (
          <>
            <img
              className="grid-col-2 inline-block veritcal-align-top margin-top-22"
              style={{display: "inline-block", marginTop: "20px", verticalAlign: "top"}}
              alt="exclamation mark inside of map pin"
              src={getAssetPath('info-pin-map.svg')}
            />
            <div className="grid-offset-1 grid-col-9 inline-block" style={{display: "inline-block"}}>
              <h3 role="status">
                {t('in_person_proofing.body.location.po_search.none_found', { address })}
              </h3>
              <p>{t('in_person_proofing.body.location.po_search.none_found_tip')}</p>
            </div>
          </>
        )}
      </>
    );
  }

  return (
    <>
      <h3 role="status">
        {!isPilot &&
          t('in_person_proofing.body.location.po_search.results_description', {
            address,
            count: locations?.length,
          })}
      </h3>
      <p>{t('in_person_proofing.body.location.po_search.results_instructions')}</p>
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
