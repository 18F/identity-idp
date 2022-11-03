import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading, SpinnerDots } from '@18f/identity-components';
import BackButton from './back-button';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';
import AnalyticsContext from '../context/analytics';
import AddressSearch from './address-search';

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
  formattedCityStateZip: string;
  id: number;
  name: string;
  phone: string;
  saturdayHours: string;
  streetAddress: string;
  sundayHours: string;
  weekdayHours: string;
}

export const LOCATIONS_URL = '/verify/in_person/usps_locations';
const getResponse = () => window.fetch(LOCATIONS_URL).then((res) => res.json());

const formatLocation = (postOffices: PostOffice[]) => {
  const formattedLocations = [] as FormattedLocation[];
  postOffices.forEach((po: PostOffice, index) => {
    const location = {
      formattedCityStateZip: `${po.city}, ${po.state}, ${po.zip_code_5}-${po.zip_code_4}`,
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

const snakeCase = (value: string) =>
  value
    .split(/(?=[A-Z])/)
    .join('_')
    .toLowerCase();

// snake case the keys of the location
const prepToSend = (location: object) => {
  const sendObject = {};
  Object.keys(location).forEach((key) => {
    sendObject[snakeCase(key)] = location[key];
  });
  return sendObject;
};

function InPersonLocationStep({ onChange, toPreviousStep }) {
  const { t } = useI18n();
  const [locationData, setLocationData] = useState([] as FormattedLocation[]);
  const [inProgress, setInProgress] = useState(false);
  const [autoSubmit, setAutoSubmit] = useState(false);
  const [isLoadingComplete, setIsLoadingComplete] = useState(false);
  const { setSubmitEventMetadata } = useContext(AnalyticsContext);

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
      const selectedLocation = locationData[id];
      const { name: selectedLocationName } = selectedLocation;
      setSubmitEventMetadata({ selected_location: selectedLocationName });
      onChange({ selectedLocationName });
      if (autoSubmit) {
        return;
      }
      // prevent navigation from continuing
      e.preventDefault();
      if (inProgress) {
        return;
      }
      const selected = prepToSend(selectedLocation);
      const headers = { 'Content-Type': 'application/json' };
      const meta: HTMLMetaElement | null = document.querySelector('meta[name="csrf-token"]');
      const csrf = meta?.content;
      if (csrf) {
        headers['X-CSRF-Token'] = csrf;
      }
      setInProgress(true);
      await fetch(LOCATIONS_URL, {
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

  const handleFoundAddress = useCallback(async () => {
    console.log('issue req')
    /* issue request for po locations */
  }, []);

  useEffect(() => {
    let mounted = true;
    (async () => {
      try {
        const fetchedLocations = await getResponse();
        if (mounted) {
          const formattedLocations = formatLocation(fetchedLocations);
          setLocationData(formattedLocations);
        }
      } finally {
        if (mounted) {
          setIsLoadingComplete(true);
        }
      }
    })();
    return () => {
      mounted = false;
    };
  }, []);

  let locationsContent: React.ReactNode;
  if (!isLoadingComplete) {
    locationsContent = <SpinnerDots />;
  } else if (locationData.length < 1) {
    locationsContent = <h4>{t('in_person_proofing.body.location.none_found')}</h4>;
  } else {
    locationsContent = (
      <LocationCollection>
        {locationData.map((item, index) => (
          <LocationCollectionItem
            key={`${index}-${item.name}`}
            handleSelect={handleLocationSelect}
            name={`${item.name} — ${t('in_person_proofing.body.location.post_office')}`}
            streetAddress={item.streetAddress}
            selectId={item.id}
            formattedCityStateZip={item.formattedCityStateZip}
            weekdayHours={item.weekdayHours}
            saturdayHours={item.saturdayHours}
            sundayHours={item.sundayHours}
          />
        ))}
      </LocationCollection>
    );
  }

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.location')}</PageHeading>
      <AddressSearch
        onAddressFound={(address) => handleFoundAddress(address)}
      />
      <p>{t('in_person_proofing.body.location.location_step_about')}</p>
      {locationsContent}
      <BackButton onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationStep;
