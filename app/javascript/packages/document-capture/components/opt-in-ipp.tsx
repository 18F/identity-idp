import { useState, useContext, useEffect } from 'react';
import { useI18n } from '@18f/identity-react-i18n';
import { FormSteps } from '@18f/identity-form-steps';
import { VerifyFlowStepIndicator, VerifyFlowPath } from '@18f/identity-verify-flow';
import { useDidUpdateEffect } from '@18f/identity-react-hooks';
import type { FormStep } from '@18f/identity-form-steps';
import { getConfigValue } from '@18f/identity-config';
import { UploadFormEntriesError } from '../services/upload';
import InPersonPrepareStep from './in-person-prepare-step';
import InPersonLocationPostOfficeSearchStep from './in-person-location-post-office-search-step';
import InPersonLocationFullAddressEntryPostOfficeSearchStep from './in-person-location-full-address-entry-post-office-search-step';
import InPersonSwitchBackStep from './in-person-switch-back-step';
import UploadContext from '../context/upload';
import AnalyticsContext from '../context/analytics';
import { InPersonContext } from '../context';

interface OptInIppProps {
  /**
   * Callback triggered on step change.
   */
  onStepChange?: () => void;
}

function OptInIpp({ onStepChange = () => { } }: OptInIppProps) {
  const [formValues, setFormValues] = useState<Record<string, any> | null>(null);
  const [submissionError, setSubmissionError] = useState<Error | undefined>(undefined);
  // todo: retrieve the step name from the URL anchor if opt-in IPP is enabled
  const [stepName, setStepName] = useState<string | undefined>(undefined);
  const { t } = useI18n();
  const { flowPath } = useContext(UploadContext);
  const { trackSubmitEvent, trackVisitEvent } = useContext(AnalyticsContext);
  const { inPersonFullAddressEntryEnabled } = useContext(InPersonContext);
  const appName = getConfigValue('appName');

  useDidUpdateEffect(onStepChange, [stepName]);
  useEffect(() => {
    if (stepName) {
      trackVisitEvent(stepName);
    }
  }, [stepName]);

  /**
   * Clears error state and sets form values for submission.
   *
   * @param nextFormValues Submitted form values.
   */
  function submitForm(nextFormValues: Record<string, any>) {
    setSubmissionError(undefined);
    setFormValues(nextFormValues);
  }

  let initialActiveErrors;
  if (submissionError instanceof UploadFormEntriesError) {
    initialActiveErrors = submissionError.formEntryErrors.map((error) => ({
      field: error.field,
      error,
    }));
  }

  let initialValues;
  if (submissionError && formValues) {
    initialValues = formValues;
  }

  const inPersonLocationPostOfficeSearchForm = inPersonFullAddressEntryEnabled
    ? InPersonLocationFullAddressEntryPostOfficeSearchStep
    : InPersonLocationPostOfficeSearchStep;

  const inPersonStepsRaw = [
    {
      name: 'prepare',
      form: InPersonPrepareStep,
      title: t('in_person_proofing.headings.prepare'),
    },
    {
      name: 'location',
      form: inPersonLocationPostOfficeSearchForm,
      title: t('in_person_proofing.headings.po_search.location'),
    },
    flowPath === 'hybrid' && {
      name: 'switch_back',
      form: InPersonSwitchBackStep,
      title: t('in_person_proofing.headings.switch_back'),
    },
  ].filter(Boolean) as FormStep[];

  const stepIndicatorPath =
    stepName && ['location', 'prepare', 'switch_back'].includes(stepName)
      ? VerifyFlowPath.IN_PERSON
      : VerifyFlowPath.DEFAULT;


  return (
    <>
      <VerifyFlowStepIndicator currentStep="document_capture" path={stepIndicatorPath} />
      <>
        <FormSteps
          steps={inPersonStepsRaw}
          initialValues={initialValues}
          initialActiveErrors={initialActiveErrors}
          onComplete={submitForm}
          onStepChange={setStepName}
          onStepSubmit={trackSubmitEvent}
          titleFormat={`%{step} - ${appName}`}
        />
      </>
    </>
  );
}

export default OptInIpp;
