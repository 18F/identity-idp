import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import useSWR from 'swr';
import BackButton from './back-button';
import AnalyticsContext from '../context/analytics';
import AddressSearch from './address-search';
import InPersonLocations, { FormattedLocation } from './in-person-locations';

interface PostOffice {
  address: string;
  city: string;
  distance: string;
  name: string;
  phone: string;
  saturday_hours: string;
  state: string;
  sunday_hours: string;
  tty: string;
  weekday_hours: string;
  zip_code_4: string;
  zip_code_5: string;
}

interface LocationQuery {
  streetAddress: string;
  city: string;
  state: string;
  zipCode: string;
  address: string;
}

export const LOCATIONS_URL = '/verify/in_person/usps_locations';

const formatLocation = (postOffices: PostOffice[]) => {
  const formattedLocations = [] as FormattedLocation[];
  postOffices.forEach((po: PostOffice, index) => {
    const location = {
      formattedCityStateZip: `${po.city}, ${po.state}, ${po.zip_code_5}-${po.zip_code_4}`,
      id: index,
      distance: po.distance,
      name: po.name,
      phone: po.phone,
      saturdayHours: po.saturday_hours,
      streetAddress: po.address,
      sundayHours: po.sunday_hours,
      tty: po.tty,
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
const transformKeys = (location: object, predicate: (key: string) => string) => {
  const sendObject = {};
  Object.keys(location).forEach((key) => {
    sendObject[predicate(key)] = location[key];
  });
  return sendObject;
};

const requestUspsLocations = async (address: LocationQuery): Promise<FormattedLocation[]> => {
  const response = await request<PostOffice[]>(LOCATIONS_URL, {
    method: 'post',
    json: { address: transformKeys(address, snakeCase) },
  });

  return formatLocation(response);
};

function InPersonLocationPostOfficeSearchStep({ onChange, toPreviousStep, registerField }) {
  const { t } = useI18n();
  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);
  const [inProgress, setInProgress] = useState(false);
  const [autoSubmit, setAutoSubmit] = useState(false);
  const { setSubmitEventMetadata } = useContext(AnalyticsContext);
  const { data: locationResults } = useSWR([LOCATIONS_URL, foundAddress], ([, address]) =>
    address ? requestUspsLocations(address) : null,
  );

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
      const selectedLocation = locationResults![id]!;
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
      const selected = transformKeys(selectedLocation, snakeCase);
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
    [locationResults, inProgress],
  );

  const handleFoundAddress = useCallback((address) => {
    setFoundAddress({
      streetAddress: address.street_address,
      city: address.city,
      state: address.state,
      zipCode: address.zip_code,
      address: address.address,
    });
  }, []);

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      <AddressSearch onAddressFound={handleFoundAddress} registerField={registerField} />
      {locationResults && (
        <InPersonLocations
          locations={locationResults}
          onSelect={handleLocationSelect}
          address={foundAddress?.address || ''}
        />
      )}
      <BackButton includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationPostOfficeSearchStep;
