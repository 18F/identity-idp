import {
  Alert,
  Button,
  IconList,
  IconListItem,
  PageHeading,
  ProcessList,
  ProcessListItem,
  SpinnerDots,
} from '@18f/identity-components';
import { removeUnloadProtection } from '@18f/identity-url';
import { useContext, useEffect, useState } from 'react';
import { FlowContext } from '@18f/identity-verify-flow';
import { useI18n } from '@18f/identity-react-i18n';
import InPersonTroubleshootingOptions from './in-person-troubleshooting-options';

const fetchSelectedLocation = () =>
  fetch('/verify/in_person/usps_locations/selected').then((response) =>
    response.json().catch((error) => {
      throw error;
    }),
  );

function InPersonPrepareStep() {
  const { t } = useI18n();
  const { inPersonURL } = useContext(FlowContext);
  const [selectedLocationName, setSelectedLocationName] = useState<string>('');
  const [hasFetchError, setHasFetchError] = useState<boolean>(false);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      const fetchedLocation = await fetchSelectedLocation().catch((error) => {
        if (cancelled) {
          return;
        }
        setHasFetchError(true);
        throw error;
      });
      setSelectedLocationName(fetchedLocation.name);
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  let selectedLocationElement: React.ReactNode;
  if (hasFetchError) {
    selectedLocationElement = null;
  } else if (selectedLocationName) {
    selectedLocationElement = (
      <Alert type="success" className="margin-bottom-4">
        {t('in_person_proofing.body.prepare.alert_selected_post_office', {
          name: selectedLocationName,
        })}
      </Alert>
    );
  } else {
    selectedLocationElement = <SpinnerDots />;
  }

  return (
    <>
      {selectedLocationElement}
      <PageHeading>{t('in_person_proofing.headings.prepare')}</PageHeading>

      <p>{t('in_person_proofing.body.prepare.verify_step_about')}</p>

      <ProcessList className="margin-bottom-4">
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_pii')}
          headingUnstyled
        />
        <ProcessListItem
          heading={t('in_person_proofing.body.prepare.verify_step_enter_phone')}
          headingUnstyled
        />
      </ProcessList>

      <hr className="margin-bottom-4" />

      <h2>{t('in_person_proofing.body.prepare.bring_title')}</h2>

      <IconList>
        <IconListItem
          icon="check_circle"
          title={t('in_person_proofing.body.prepare.bring_barcode_header')}
        >
          <p>{t('in_person_proofing.body.prepare.bring_barcode_info')}</p>
        </IconListItem>

        <IconListItem
          icon="check_circle"
          title={t('in_person_proofing.body.prepare.bring_id_header')}
        >
          <p>{t('in_person_proofing.body.prepare.bring_id_info_acceptable')}</p>
          <ul>
            <li>{t('in_person_proofing.body.prepare.bring_id_info_dl')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_id_info_id_card')}</li>
          </ul>
          <p>{t('in_person_proofing.body.prepare.bring_id_info_no_other_forms')}</p>
        </IconListItem>

        <IconListItem
          icon="check_circle"
          title={t('in_person_proofing.body.prepare.bring_proof_header')}
        >
          <p>{t('in_person_proofing.body.prepare.bring_proof_info_acceptable')}</p>
          <ul>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_lease')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_registration')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_card')}</li>
            <li>{t('in_person_proofing.body.prepare.bring_proof_info_policy')}</li>
          </ul>
        </IconListItem>
      </IconList>
      {inPersonURL && (
        <div className="margin-y-5">
          <Button href={inPersonURL} onClick={removeUnloadProtection} isBig isWide>
            {t('forms.buttons.continue')}
          </Button>
        </div>
      )}
      <InPersonTroubleshootingOptions />
    </>
  );
}

export default InPersonPrepareStep;
