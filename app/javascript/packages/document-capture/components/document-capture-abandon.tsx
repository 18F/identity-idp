import { Tag, Checkbox, FieldSet, Button } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';

function DocumentCaptureAbandon() {
  const { t } = useI18n();

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
  const idTypes = [
    'us_passport',
    'resident_card',
    'military_id',
    'tribal_id',
    'voter_registration_card',
    'other',
  ];

  const idTypeLabels = [
    t('doc_auth.exit_survey_id_types.us_passport'),
    t('doc_auth.exit_survey_id_types.resident_card'),
    t('doc_auth.exit_survey_id_types.military_id'),
    t('doc_auth.exit_survey_id_types.tribal_id'),
    t('doc_auth.exit_survey_id_types.voter_registration_card'),
    t('doc_auth.exit_survey_id_types.other'),
  ];

  const checkboxes = idTypes.map((idType, idx) => (
    <Checkbox key={idType} name={idType} value={idType} label={idTypeLabels[idx]} />
  ));
  return (
    <>
      {header}
      {content}
      {optionalTag}
      {optionalText}
      <FieldSet legend="Optional. Select any of the documents you have.">{checkboxes}</FieldSet>
      <Button isOutline>Submit and exit Login.gov</Button>
    </>
  );
}

export default DocumentCaptureAbandon;
