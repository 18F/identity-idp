import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { request } from '@18f/identity-request';
import { forceRedirect } from '@18f/identity-url';
import { FullAddressSearch, transformKeys, snakeCase } from '@18f/identity-address-search';
import type { FormattedLocation } from '@18f/identity-address-search/types';
import BackButton from './back-button';
import AnalyticsContext from '../context/analytics';
import { InPersonContext } from '../context';
import UploadContext from '../context/upload';

function InPersonLocationFullAddressEntryPostOfficeSearchStep({
  onChange,
  toPreviousStep,
  registerField,
}) {
  const { inPersonURL, locationsURL, usStatesTerritories } = useContext(InPersonContext);
  const [inProgress, setInProgress] = useState<boolean>(false);
  const [autoSubmit, setAutoSubmit] = useState<boolean>(false);
  const { trackEvent, setSubmitEventMetadata } = useContext(AnalyticsContext);
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
    async (e: any, id: number | null) => {
      const isNullLocation = id === null;
      const selectedLocation = isNullLocation ? null : locationResults![id];

      const selectedLocationAddress = isNullLocation
        ? 'Location Selection Skipped'
        : `${selectedLocation?.streetAddress}, ${selectedLocation?.formattedCityStateZip}`;

      if (flowPath !== 'hybrid') {
        e.preventDefault();
      } else {
        setSubmitEventMetadata({ selected_location: selectedLocationAddress });
      }

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

      const selectedLocationDto = {
        selected_location: isNullLocation ? null : transformKeys(selectedLocation!, snakeCase),
      };

      setInProgress(true);

      try {
        await request(locationsURL, {
          json: selectedLocationDto,
          method: 'PUT',
        });

        // In try block set success of request. If the request is successful, fire remaining code?
        if (mountedRef.current) {
          setAutoSubmit(true);
          setImmediate(() => {
            e.target.disabled = false;

            // Skip analytics track event since hybrid has its own logging
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
        locationsURL={locationsURL}
        handleLocationSelect={handleLocationSelect}
        usStatesTerritories={usStatesTerritories}
        usesErrorComponent
      />
      <BackButton role="link" includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationFullAddressEntryPostOfficeSearchStep;
