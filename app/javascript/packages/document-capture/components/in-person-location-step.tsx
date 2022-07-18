import { useState, useEffect } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading, LocationCollectionItem, LocationCollection } from '@18f/identity-components';
import { LocationCollectionItemProps } from '@18f/identity-components/location-collection-item';

interface PostOffice {
  address: string;
  city: string;
  name: string;
  saturday_hours: string;
  state: string;
  sunday_hours: string;
  weekday_hours: string;
  zip_code_4: string;
  zip_code_5: string;
}

const getResponse = async () => {
  const response = await fetch('http://localhost:3000/verify/in_person/usps_locations').then(
    (res) =>
      res.json().catch((error) => {
        throw error;
      }),
  );
  return response;
};

const formatLocation = (postOffices: { postOffices: PostOffice[] }) => {
  const formattedLocations = [] as LocationCollectionItemProps[];
  postOffices.forEach((po) => {
    const location = {
      name: po.name,
      streetAddress: po.address,
      addressLine2: `${po.city}, ${po.state}, ${po.zip_code_5}-${po.zip_code_4}`,
      weekdayHours: po.weekday_hours,
      saturdayHours: po.saturday_hours,
      sundayHours: po.sunday_hours,
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
      const fetchedLocations = await getResponse().catch((error) => {
        throw error;
      });
      const formattedLocations = formatLocation(fetchedLocations);
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
              key={item.name}
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
