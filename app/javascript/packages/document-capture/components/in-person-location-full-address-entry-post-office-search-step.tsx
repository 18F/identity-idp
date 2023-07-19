import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { Alert, PageHeading } from '@18f/identity-components';
import { request } from '@18f/identity-request';
import { forceRedirect } from '@18f/identity-url';
import BackButton from './back-button';
import AnalyticsContext from '../context/analytics';
import InPersonLocations, { FormattedLocation } from './in-person-locations';
import { InPersonContext } from '../context';
import UploadContext from '../context/upload';

function InPersonLocationFullAddressEntryPostOfficeSearchStep({ onChange, toPreviousStep }) {
  const { inPersonURL } = useContext(InPersonContext);
  const { t } = useI18n();
  const [inProgress, setInProgress] = useState<boolean>(false);
  const [isLoadingLocations] = useState<boolean>(false);
  const [autoSubmit, setAutoSubmit] = useState<boolean>(false);
  const { trackEvent } = useContext(AnalyticsContext);
  const [locationResults] = useState<FormattedLocation[] | null | undefined>(null);
  const [foundAddress] = useState<LocationQuery | null>(null);
  const [apiError] = useState<Error | null>(null);
  const [, setDisabledAddressSearch] = useState<boolean>(false);
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
      {apiError && (
        <Alert type="error" className="margin-bottom-4">
          {t('idv.failure.exceptions.post_office_search_error')}
        </Alert>
      )}
      <PageHeading>{t('in_person_proofing.headings.po_search.location')}</PageHeading>
      <p>{t('in_person_proofing.body.location.po_search.po_search_about')}</p>
      {locationResults && foundAddress && !isLoadingLocations && (
        <InPersonLocations
          locations={locationResults}
          onSelect={handleLocationSelect}
          address={foundAddress?.address || ''}
        />
      )}
      <BackButton role="link" includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationFullAddressEntryPostOfficeSearchStep;
