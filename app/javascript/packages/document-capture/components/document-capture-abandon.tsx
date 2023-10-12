import { Tag, Checkbox, FieldSet, Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { useContext, useState } from 'react';
import AnalyticsContext from '../context/analytics';

function DocumentCaptureAbandon() {
  const { t } = useI18n();
  const { trackEvent } = useContext(AnalyticsContext);

  const header = <h3>Don&amp;apos;t have a driver;apos;s licnese or State ID?</h3>;
  const content = (
    <p>
      If you dont have a driver;apos;s licens or state ID card, you cannot continu with Loging.gov.
      Please exit Login.gov and contact[Partner Agency] to find out what you can do.
    </p>
  );

  const optionalTag = <Tag isBig={false}>Optional</Tag>;

  const optionalText = (
    <p>
      Help us add more identity documents to Login.gov. Which types of identity documents do you
      have instead?
    </p>
  );

  const idTypeLabels = [
    t('doc_auth.exit_survey_id_types.us_passport'),
    t('doc_auth.exit_survey_id_types.resident_card'),
    t('doc_auth.exit_survey_id_types.military_id'),
    t('doc_auth.exit_survey_id_types.tribal_id'),
    t('doc_auth.exit_survey_id_types.voter_registration_card'),
    t('doc_auth.exit_survey_id_types.other'),
  ];

  const allIdTypeOptions = [
    { name: 'us_passport', checked: false },
    { name: 'resident_card', checked: false },
    { name: 'military_id', checked: false },
    { name: 'tribal_id', checked: false },
    { name: 'voter_registration_card', checked: false },
    { name: 'other', checked: false },
  ];

  const [idTypeOptions, setIdTypeOptions] = useState(allIdTypeOptions);

  const updateCheckStatus = (index: number) => {
    setIdTypeOptions(
      idTypeOptions.map((id_option, currentIndex) =>
        currentIndex === index ? { ...id_option, checked: !id_option.checked } : { ...id_option },
      ),
    );
  };

  const checkboxes = idTypeOptions.map((idType, idx) => (
    <Checkbox
      key={idType.name}
      name={idType.name}
      value={idType.name}
      label={idTypeLabels[idx]}
      onChange={() => updateCheckStatus(idx)}
    />
  ));

  const handleExit = () => {
    trackEvent('IdV: exit optional id types', { ids: idTypeOptions });
    window.location.href = '/verify/exit?step=document-capture&location=optional_question';
  };

  return (
    <>
      {header}
      {content}
      {optionalTag}
      {optionalText}
      <FieldSet legend="Optional. Select any of the documents you have.">{checkboxes}</FieldSet>
      <Button isOutline onClick={handleExit}>
        Submit and exit Login.gov
      </Button>
    </>
  );
}

export default DocumentCaptureAbandon;
