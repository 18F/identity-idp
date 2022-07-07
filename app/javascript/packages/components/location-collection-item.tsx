import type { ReactNode } from 'react';
import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

// TODO: update props to be a locationItemObject
// TODO: create locationItemObject based on data returned by API, should be separate file, need to look at api to determine fields
interface LocationCollectionItemProps {
  header: string;
  addressLine1: string;
  addressLine2: string;
  hoursWD: string;
  hoursSat: string;
  hoursSun: string;
}

// TODO: create strings in i18n for days and import here
// flex-row doesn't work; flex-column does but the 2 items are now in a col together and stacked on top of each other
// this means the ui as is does not match the figma file
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
        <div className="display-flex flex-column">
          <div className="flex-align-self-end">
            <Button>{t('in_person_proofing.body.location.location_button')}</Button>
          </div>
          <div className="flex-align-self-start">
            <h3 className="usa-collection__heading">{header}</h3>
          </div>
        </div>
        <div>{addressLine1}</div>
        <div>{addressLine2}</div>
        <h4>{t('in_person_proofing.body.location.retail_hours_heading')}</h4>
        <div>{hoursWD}</div>
        <div>{hoursSat}</div>
        <div>{hoursSun}</div>
      </div>
    </li>
  );
}

export default LocationCollectionItem;
