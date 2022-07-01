import type { ReactNode } from 'react';
import { Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
// import fails
import './location-collection-item.scss';

// TODO: update props to be a locationItemObject
// TODO: create locationItemObject based on data returned by API, should be separate file, need to look at api to determine fields
interface LocationCollectionItemProps {
  header: string;
  addressLine1: string;
  addressLine2: string;
  hoursWD: string;
  hoursSat: string;
  hoursSun: string;
  children: ReactNode;
}

// TODO: need a styles.scss that includes @import './components/location-collection-item'; but needs to be separate from
// the one that already exists

// TODO: create strings in i18n for days and import here
// flex-row doesn't work; flex-column does but the 2 items are now in a col together and stacked on top of each other
// this means the ui as is does not match the figma file
function LocationCollectionItem({ header, children }: LocationCollectionItemProps) {
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
        <div>900 E FAYETTE ST RM 118</div>
        <div>BALTIMORE, MD 21233-9715</div>
        <h4>{t('in_person_proofing.body.location.retail_hours_heading')}</h4>
        <div>Mon-Fri: 8:30 am-7:00 pm</div>
        <div>Sat: 8:30 am-5:00 pm</div>
        <div>Sun: Closed</div>
      </div>
    </li>
  );
}

export default LocationCollectionItem;
