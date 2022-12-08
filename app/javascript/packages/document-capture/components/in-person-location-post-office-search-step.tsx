import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading, SpinnerDots } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import BackButton from './back-button';
import LocationCollection from './location-collection';
import LocationCollectionItem from './location-collection-item';
import AnalyticsContext from '../context/analytics';
import AddressSearch from './address-search';
import InPersonContext from '../context/in-person';

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
interface LocationQuery {
  streetAddress: string;
  city: string;
  state: string;
  zipCode: string;
}

export const LOCATIONS_URL = '/verify/in_person/usps_locations';

const getUspsLocations = (address) =>
  request(LOCATIONS_URL, {
    method: 'post',
    json: { address },
  });

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

function InPersonLocationPostOfficeSearchStep({ onChange, toPreviousStep, registerField }) {
  const { t } = useI18n();
  const [locationData, setLocationData] = useState([] as FormattedLocation[]);
  const [foundAddress, setFoundAddress] = useState({} as LocationQuery);
  const [inProgress, setInProgress] = useState(false);
  const [autoSubmit, setAutoSubmit] = useState(false);
  const [isLoadingComplete, setIsLoadingComplete] = useState(false);
  const { setSubmitEventMetadata } = useContext(AnalyticsContext);
  const { arcgisSearchEnabled } = useContext(InPersonContext);

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
      setInProgress(true);
      await request(LOCATIONS_URL, {
        json: selected,
        method: 'PUT',
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

  const handleFoundAddress = useCallback((address) => {
    setFoundAddress({
      streetAddress: address.street_address,
      city: address.city,
      state: address.state,
      zipCode: address.zip_code,
    });
  }, []);

  useEffect(() => {
    let didCancel = false;
    (async () => {
      try {
        const fetchedLocations = await getUspsLocations(prepToSend(foundAddress));

        if (!didCancel) {
          const formattedLocations = formatLocation(fetchedLocations);
          setLocationData(formattedLocations);
        }
      } finally {
        if (!didCancel) {
          setIsLoadingComplete(true);
        }
      }
    })();
    return () => {
      didCancel = true;
    };
  }, [foundAddress]);

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
      {arcgisSearchEnabled && (
        <AddressSearch onAddressFound={handleFoundAddress} registerField={registerField} />
      )}
      <p>{t('in_person_proofing.body.location.location_step_about')}</p>
      {locationsContent}
      <BackButton onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationPostOfficeSearchStep;
