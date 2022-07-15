import { useState, useEffect } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import {
  PageHeading,
  LocationCollectionItem,
  LocationCollection,
  LocationCollectionItemProps,
} from '@18f/identity-components';

const getResponse = async () => {
  const response = await fetch('http://localhost:3000/verify/in_person/usps_locations').then(
    (res) =>
      res.json().catch((error) => {
        throw error;
      }),
  );
  return response;
};

const formatAddressline = (postOffice: { city: any; state: any; zip5: any; zip4: any }) =>
  `${postOffice.city}, ${postOffice.state}, ${postOffice.zip5}-${postOffice.zip4}`;

const formatLocation = (postOffices: { postOffices: LocationCollectionItemProps[] }) => {
  const formattedLocations = [] as LocationCollectionItemProps[];
  postOffices.postOffices.forEach((po) => {
    const location = {
      name: po.name,
      streetAddress: po.streetAddress,
      addressLine2: formatAddressline(po),
      weekdayHours: po.hours[0].weekdayHours,
      saturdayHours: po.hours[1].saturdayHours,
      sundayHours: po.hours[2].sundayHours,
    } as LocationCollectionItemProps;
    formattedLocations.push(location);
  });
  return formattedLocations;
};

function InPersonLocationStep() {
  const { t } = useI18n();
  const [locationData, setLocationData] = useState([] as LocationCollectionItemProps[]);

  useEffect(() => {
    (async () => {
      const fetchedPosts = await getResponse().catch((error) => {
        throw error;
      });
      const formattedLocations = formatLocation(fetchedPosts);
      setLocationData(formattedLocations);
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
              name={`${item.name} — ${t('in_person_proofing.body.location.post_office')}`}
              streetAddress={item.streetAddress}
              addressLine2={item.addressLine2}
              weekdayHours={item.weekdayHours}
              saturdayHours={item.saturdayHours}
              sundayHours={item.sundayHours}
            />
          ))}
        {locationData.length < 1 && <h4>No locations found.</h4>}
      </LocationCollection>
    </>
  );
}

export default InPersonLocationStep;
