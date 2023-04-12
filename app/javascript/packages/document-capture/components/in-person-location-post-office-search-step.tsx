import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { Alert, PageHeading } from '@18f/identity-components';
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
import { InPersonContext } from '../context';

function InPersonLocationPostOfficeSearchStep({ onChange, toPreviousStep, registerField }) {
  const { inPersonCtaVariantActive } = useContext(InPersonContext);
  const { t } = useI18n();
  const [inProgress, setInProgress] = useState<boolean>(false);
  const [isLoadingLocations, setLoadingLocations] = useState<boolean>(false);
  const [autoSubmit, setAutoSubmit] = useState<boolean>(false);
  const { setSubmitEventMetadata } = useContext(AnalyticsContext);
  const [locationResults, setLocationResults] = useState<FormattedLocation[] | null | undefined>(
    null,
  );
  const [foundAddress, setFoundAddress] = useState<LocationQuery | null>(null);
  const [apiError, setApiError] = useState<Error | null>(null);
  const [disabledAddressSearch, setDisabledAddressSearch] = useState<boolean>(false);

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
      const { streetAddress, formattedCityStateZip } = selectedLocation;
      const selectedLocationAddress = `${streetAddress}, ${formattedCityStateZip}`;
      setSubmitEventMetadata({
        selected_location: selectedLocationAddress,
        in_person_cta_variant: inPersonCtaVariantActive,
      });
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
      // prevent navigation from continuing
      e.preventDefault();
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
        if (mountedRef.current) {
          setAutoSubmit(true);
          setImmediate(() => {
            // continue with navigation
            e.target.disabled = false;
            e.target.click();
            // allow process to be re-triggered in case submission did not work as expected
            setAutoSubmit(false);
          });
        }
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
      <AddressSearch
        registerField={registerField}
        onFoundAddress={setFoundAddress}
        onFoundLocations={setLocationResults}
        onLoadingLocations={setLoadingLocations}
        onError={setApiError}
        disabled={disabledAddressSearch}
      />
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

export default InPersonLocationPostOfficeSearchStep;
