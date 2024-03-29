import { Tag, Checkbox, FieldSet, Button, Link } from '@18f/identity-components';
import { useI18n } from '@18f/identity-react-i18n';
import { useContext, useState } from 'react';
import FlowContext from '@18f/identity-verify-flow/context/flow-context';
import formatHTML from '@18f/identity-react-i18n/format-html';
import { addSearchParams, forceRedirect, Navigate } from '@18f/identity-url';
import { getConfigValue } from '@18f/identity-config';
import AnalyticsContext from '../context/analytics';
import { ServiceProviderContext } from '../context';

function formatContentHtml({ msg, url }) {
  return formatHTML(msg, {
    a: ({ children }) => (
      <Link href={url} isExternal={false}>
        {children}
      </Link>
    ),
    strong: ({ children }) => <strong>{children}</strong>,
  });
}

export interface DocumentCaptureAbandonProps {
  navigate?: Navigate;
}

function DocumentCaptureAbandon({ navigate }: DocumentCaptureAbandonProps) {
  const { t } = useI18n();
  const { trackEvent } = useContext(AnalyticsContext);
  const { currentStep, exitURL, cancelURL } = useContext(FlowContext);
  const { name: spName } = useContext(ServiceProviderContext);
  const appName = getConfigValue('appName');
  const header = <h2 className="h3">{t('doc_auth.exit_survey.header')}</h2>;

  const content = (
    <p>
      {formatContentHtml({
        msg: spName?.trim()
          ? t('doc_auth.exit_survey.content_html', {
              sp_name: spName,
              app_name: appName,
            })
          : t('doc_auth.exit_survey.content_nosp_html', {
              app_name: appName,
            }),
        url: addSearchParams(spName?.trim() ? exitURL : cancelURL, {
          step: currentStep,
          location: 'optional_question',
        }),
      })}
    </p>
  );
  const optionalTag = (
    <Tag isBig={false} isInformative>
      {t('doc_auth.exit_survey.optional.tag', { app_name: appName })}
    </Tag>
  );
  const optionalText = (
    <p className="margin-top-2">
      <strong>{t('doc_auth.exit_survey.optional.content', { app_name: appName })}</strong>
    </p>
  );

  const idTypeLabels = [
    t('doc_auth.exit_survey.optional.id_types.us_passport'),
    t('doc_auth.exit_survey.optional.id_types.resident_card'),
    t('doc_auth.exit_survey.optional.id_types.military_id'),
    t('doc_auth.exit_survey.optional.id_types.tribal_id'),
    t('doc_auth.exit_survey.optional.id_types.voter_registration_card'),
    t('doc_auth.exit_survey.optional.id_types.other'),
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
      idTypeOptions.map((idOption, currentIndex) =>
        currentIndex === index ? { ...idOption, checked: !idOption.checked } : { ...idOption },
      ),
    );
  };

  const checkboxes = (
    <>
      {idTypeOptions.map((idType, idx) => (
        <Checkbox
          key={idType.name}
          name={idType.name}
          value={idType.name}
          label={idTypeLabels[idx]}
          onChange={() => updateCheckStatus(idx)}
        />
      ))}
    </>
  );

  const handleExit = () => {
    trackEvent('IdV: exit optional questions', { ids: idTypeOptions });
    forceRedirect(
      addSearchParams(spName ? exitURL : cancelURL, {
        step: currentStep,
        location: 'optional_question',
      }),
      navigate,
    );
  };

  return (
    <>
      {header}
      {content}
      <div className="document-capture-optional-questions">
        {optionalTag}
        {optionalText}
        <FieldSet legend={t('doc_auth.exit_survey.optional.legend')}>{checkboxes}</FieldSet>
        <Button isOutline className="margin-top-3" onClick={handleExit}>
          {t('doc_auth.exit_survey.optional.button', { app_name: appName })}
        </Button>
        <div className="usa-prose margin-top-3">
          {t('idv.legal_statement.information_collection')}
        </div>
      </div>
    </>
  );
}

export default DocumentCaptureAbandon;
