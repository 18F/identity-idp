import { useState, useEffect } from 'react';
import { PageHeading, LocationCollectionItem, LocationCollection } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

/**
 * @typedef InPersonLocationStepValue
 *
 * @prop {Blob|string|null|undefined} inPersonLocation InPersonLocation value.
 */

/**
 * @param {import('@18f/identity-form-steps').FormStepComponentProps<InPersonLocationStepValue>} props Props object.
 */

const getResponse = async () => {
  const response = await fetch('http://localhost:3000/verify/in_person/usps_locations').then(
    // TODO: error handling
    // eslint-disable-next-line no-console
    (res) => res.json().catch((error) => console.log('error', error)),
  );
  return response;
};

// TODO: should move object definition - it is the same as the locationItemProps interface
function InPersonLocationStep() {
  const [locationData, setLocationData] = useState(
    [] as {
      name: string;
      streetAddress: string;
      addressLine2: string;
      weekdayHours: string;
      saturdayHours: string;
      sundayHours: string;
    }[],
  );

  const { t } = useI18n();

  useEffect(() => {
    (async () => {
      const fetchedPosts = await getResponse();
      setLocationData(fetchedPosts);
    })();
  }, []);

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.location')}</PageHeading>

      <p>{t('in_person_proofing.body.location.location_step_about')}</p>
      <LocationCollection>
        {locationData &&
          locationData.map((item) => (
            <LocationCollectionItem
              name={`${item.name} ${t('in_person_proofing.body.location.post_office')}`}
              streetAddress={item.streetAddress}
              addressLine2={item.addressLine2}
              weekdayHours={item.weekdayHours}
              saturdayHours={item.saturdayHours}
              sundayHours={item.sundayHours}
            />
          ))}
      </LocationCollection>
    </>
  );
}

export default InPersonLocationStep;
