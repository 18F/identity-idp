import { useState, useEffect, useCallback, useRef } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading, LocationCollectionItem, LocationCollection } from '@18f/identity-components';

interface PostOffice {
  address: string;
  city: string;
  name: string;
  phone: string;
  saturday_hours: string;
  state: string;
  sunday_hours: string;
  weekday_hours: string;
  zip_code_4: string;
  zip_code_5: string;
}

interface FormattedLocation {
  addressLine2: string;
  id: number;
  name: string;
  phone: string;
  saturdayHours: string;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

const locationUrl = '/verify/in_person/usps_locations';

const getResponse = async () => {
  const response = await fetch(locationUrl).then((res) =>
    res.json().catch((error) => {
      throw error;
    }),
  );
  return response;
};

const formatLocation = (postOffices: PostOffice[]) => {
  const formattedLocations = [] as FormattedLocation[];
  postOffices.forEach((po: PostOffice, index) => {
    const location = {
      addressLine2: `${po.city}, ${po.state}, ${po.zip_code_5}-${po.zip_code_4}`,
      id: index,
      name: po.name,
      phone: po.phone,
      saturdayHours: po.saturday_hours,
      streetAddress: po.address,
      sundayHours: po.sunday_hours,
      weekdayHours: po.weekday_hours,
    } as FormattedLocation;
    formattedLocations.push(location);
  });
  return formattedLocations;
};

function InPersonLocationStep() {
  const { t } = useI18n();
  const [locationData, setLocationData] = useState([] as FormattedLocation[]);
  const [inProgress, setInProgress] = useState(false);
  const [autoSubmit, setAutoSubmit] = useState(false);

  // ref allows us to avoid a memory leak
  const mountedRef = useRef(false);

  useEffect(() => {
    mountedRef.current = true;
    return () => {
      mountedRef.current = false;
    };
  }, []);

  // useCallBack here prevents unnecessary rerenders due to changing function identity
  const handleLocationSelect = useCallback(
    async (e: any, id: number) => {
      if (autoSubmit) {
        return;
      }
      // prevent navigation from continuing
      e.preventDefault();
      if (inProgress) {
        return;
      }
      const selected = locationData[id];
      const headers = { 'Content-Type': 'application/json' };
      const meta: HTMLMetaElement | null = document.querySelector('meta[name="csrf-token"]');
      const csrf = meta?.content;
      if (csrf) {
        headers['X-CSRF-Token'] = csrf;
      }
      setInProgress(true);
      await fetch(locationUrl, {
        method: 'PUT',
        body: JSON.stringify(selected),
        headers,
      })
        .then(() => {
          if (!mountedRef.current) {
            return;
          }
          setAutoSubmit(true);
          setImmediate(() => {
            // continue with navigation
            e.target.click();
            // allow process to be re-triggered in case submission did not work as expected
            setAutoSubmit(false);
          });
        })
        .finally(() => {
          if (!mountedRef.current) {
            return;
          }
          setInProgress(false);
        });
    },
    [locationData, inProgress],
  );

  useEffect(() => {
    (async () => {
      const fetchedLocations = await getResponse().catch((error) => {
        throw error;
      });
      if (!mountedRef.current) {
        return;
      }
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
          locationData.map((item, index) => (
            <LocationCollectionItem
              key={`${index}-${item.name}`}
              handleSelect={handleLocationSelect}
              name={`${item.name} — ${t('in_person_proofing.body.location.post_office')}`}
              streetAddress={item.streetAddress}
              selectId={item.id}
              addressLine2={item.addressLine2}
              weekdayHours={item.weekdayHours}
              saturdayHours={item.saturdayHours}
              sundayHours={item.sundayHours}
            />
          ))}
        {locationData.length < 1 && <h4>{t('in_person_proofing.body.location.none_found')}</h4>}
      </LocationCollection>
    </>
  );
}

export default InPersonLocationStep;
