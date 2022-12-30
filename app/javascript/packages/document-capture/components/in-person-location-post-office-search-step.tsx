import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { PageHeading } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import BackButton from './back-button';
import AnalyticsContext from '../context/analytics';
import AddressSearch, {
  transformKeys,
  snakeCase,
  LocationQuery,
  LOCATIONS_URL,
} from './address-search';
import InPersonLocations, { FormattedLocation } from './in-person-locations';

function InPersonLocationPostOfficeSearchStep({ onChange, toPreviousStep, registerField }) {
  const { t } = useI18n();
  const [inProgress, setInProgress] = useState(false);
  const [autoSubmit, setAutoSubmit] = useState(false);
  const { setSubmitEventMetadata } = useContext(AnalyticsContext);
  const [locationResults, setLocationResults] = useState<FormattedLocation[] | null>(null);
  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);

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

  return (
    <>
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      <AddressSearch
        registerField={registerField}
        onFoundAddress={setFoundAddress}
        onFoundLocations={setLocationResults}
      />
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
