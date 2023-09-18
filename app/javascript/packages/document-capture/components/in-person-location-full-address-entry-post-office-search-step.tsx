import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { request } from '@18f/identity-request';
import { forceRedirect } from '@18f/identity-url';
import { transformKeys, snakeCase } from '@18f/identity-address-search';
import type { FormattedLocation } from '@18f/identity-address-search/types';
import FullAddressSearch from './in-person-full-address-search';
import BackButton from './back-button';
import AnalyticsContext from '../context/analytics';
import { InPersonContext } from '../context';
import UploadContext from '../context/upload';
import { LOCATIONS_URL } from './in-person-location-post-office-search-step';

function InPersonLocationFullAddressEntryPostOfficeSearchStep({
  onChange,
  toPreviousStep,
  registerField,
}) {
  const { inPersonURL } = useContext(InPersonContext);
  const [inProgress, setInProgress] = useState<boolean>(false);
  const [autoSubmit, setAutoSubmit] = useState<boolean>(false);
  const { trackEvent } = useContext(AnalyticsContext);
  const [locationResults, setLocationResults] = useState<FormattedLocation[] | null | undefined>(
    null,
  );
  const [disabledAddressSearch, setDisabledAddressSearch] = useState<boolean>(false);
  const { flowPath } = useContext(UploadContext);

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
      if (flowPath !== 'hybrid') {
        e.preventDefault();
      }
      const selectedLocation = locationResults![id]!;
      const { streetAddress, formattedCityStateZip } = selectedLocation;
      const selectedLocationAddress = `${streetAddress}, ${formattedCityStateZip}`;
      onChange({ selectedLocationAddress });
      if (autoSubmit) {
        setDisabledAddressSearch(true);
        setTimeout(() => {
          if (mountedRef.current) {
            setDisabledAddressSearch(false);
          }
        }, 250);
        return;
      }
      if (inProgress) {
        return;
      }
      const selected = transformKeys(selectedLocation, snakeCase);
      setInProgress(true);
      try {
        await request(LOCATIONS_URL, {
          json: selected,
          method: 'PUT',
        });
        // In try block set success of request. If the request is successful, fire remaining code?
        if (mountedRef.current) {
          setAutoSubmit(true);
          setImmediate(() => {
            e.target.disabled = false;
            if (flowPath !== 'hybrid') {
              trackEvent('IdV: location submitted', {
                selected_location: selectedLocationAddress,
              });
              forceRedirect(inPersonURL!);
            }
            // allow process to be re-triggered in case submission did not work as expected
            setAutoSubmit(false);
          });
        }
      } catch {
        setAutoSubmit(false);
      } finally {
        if (mountedRef.current) {
          setInProgress(false);
        }
      }
    },
    [locationResults, inProgress],
  );

  return (
    <>
      <FullAddressSearch
        registerField={registerField}
        onFoundLocations={setLocationResults}
        disabled={disabledAddressSearch}
        locationsURL={LOCATIONS_URL}
        handleLocationSelect={handleLocationSelect}
      />
      <BackButton role="link" includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationFullAddressEntryPostOfficeSearchStep;
