import { useState, useEffect, useCallback, useRef, useContext } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { request } from '@18f/identity-request';
import { forceRedirect } from '@18f/identity-url';
import { transformKeys, snakeCase } from '@18f/identity-address-search';
import type { FormattedLocation } from '@18f/identity-address-search/types';
import BackButton from './back-button';
import AnalyticsContext from '../context/analytics';
import { InPersonContext } from '../context';
import UploadContext from '../context/upload';
import AddressSearch from './address-search';

export const LOCATIONS_URL = new URL(
  '/verify/in_person/usps_locations',
  window.location.href,
).toString();
export const ADDRESSES_URL = new URL('/api/addresses', window.location.href).toString();

function InPersonLocationPostOfficeSearchStep({ onChange, toPreviousStep, registerField }) {
  const { t } = useI18n();
  const { inPersonURL } = useContext(InPersonContext);
  const [inProgress, setInProgress] = useState<boolean>(false);
  const [autoSubmit, setAutoSubmit] = useState<boolean>(false);
  const { trackEvent } = useContext(AnalyticsContext);
  const [locationResults, setLocationResults] = useState<FormattedLocation[] | null | undefined>(
    null,
  );

  const [disabledAddressSearch, setDisabledAddressSearch] = useState<boolean>(false);
  const { flowPath } = useContext(UploadContext);

  
  // temp for testing- remove this!
  // 1. translations need to be moved
  // 2. need to set up state to pass into address-search in addition to component
  // const [address, setAddress] = useState('');
  const NoResultsHelpCenterMessage = ({ address }) => {
    // console.log('searchAddress inside original: ', address);
    // const address = address;
    return (
      <div className="grid-col-12 inline-block" style={{display: "inline-block"}}>
        <h3 role="status">
          {t('in_person_proofing.body.location.po_search.none_found', {address} )}
        </h3>
        <p>{t('in_person_proofing.body.location.po_search.none_found_tip')}</p>
      </div>
    )
  }

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
      <AddressSearch
        registerField={registerField}
        onFoundLocations={setLocationResults}
        handleLocationSelect={handleLocationSelect}
        disabled={disabledAddressSearch}
        locationsURL={LOCATIONS_URL}
        addressSearchURL={ADDRESSES_URL}
        // NoResultsHelpCenterMessage={undefined}
        // setSearchAddress={undefined}
        NoResultsHelpCenterMessage={NoResultsHelpCenterMessage}
        // setSearchAddress={setAddress}
      />
      <BackButton role="link" includeBorder onClick={toPreviousStep} />
    </>
  );
}

export default InPersonLocationPostOfficeSearchStep;
