import type { FormStep } from '@18f/identity-form-steps';
import { useI18n } from '@18f/identity-react-i18n';
import { UploadFormEntriesError } from '../services/upload';
import DocumentsStep from '../components/documents-step';
import InPersonPrepareStep from '../components/in-person-prepare-step';
import InPersonLocationPostOfficeSearchStep from '../components/in-person-location-post-office-search-step';
import InPersonLocationFullAddressEntryPostOfficeSearchStep from '../components/in-person-location-full-address-entry-post-office-search-step';
import InPersonSwitchBackStep from '../components/in-person-switch-back-step';
import ReviewIssuesStep from '../components/review-issues-step';
import withProps from '../higher-order/with-props';

const getReviewStep = (submissionError) => {
  const { t } = useI18n();

  return {
    name: 'review',
    form:
      submissionError instanceof UploadFormEntriesError
        ? withProps({
            remainingAttempts: submissionError.remainingAttempts,
            isFailedResult: submissionError.isFailedResult,
            isFailedDocType: submissionError.isFailedDocType,
            captureHints: submissionError.hints,
            pii: submissionError.pii,
            failedImageFingerprints: submissionError.failed_image_fingerprints,
          })(ReviewIssuesStep)
        : ReviewIssuesStep,
    title: t('errors.doc_auth.rate_limited_heading'),
  };
};

export const getSteps = (
  submissionError,
  inPersonURL,
  inPersonFullAddressEntryEnabled,
  flowPath,
) => {
  const { t } = useI18n();

  // getReviewStep needs to be called even if we're not going to use it because it contains
  // a hook (in a context). Conditionally calling a hook causes problems in React, so
  // always calling getReviewStep is necessary
  const reviewStep: FormStep = getReviewStep(submissionError);

  // When there's no submission error, the only step is the 'documents' step where we upload images.
  if (!submissionError) {
    return [
      {
        name: 'documents',
        form: DocumentsStep,
        title: t('doc_auth.headings.document_capture'),
      },
    ];
  }

  // Change the location step UI based on the current full address entry setting
  const locationStep: FormStep = inPersonFullAddressEntryEnabled
    ? {
        name: 'location',
        form: InPersonLocationFullAddressEntryPostOfficeSearchStep,
        title: t('in_person_proofing.headings.po_search.location'),
      }
    : {
        name: 'location',
        form: InPersonLocationPostOfficeSearchStep,
        title: t('in_person_proofing.headings.po_search.location'),
      };

  const inPersonProofingSteps: FormStep[] = !inPersonURL
    ? []
    : [
        {
          name: 'prepare',
          form: InPersonPrepareStep,
          title: t('in_person_proofing.headings.prepare'),
        },
        locationStep,
      ];

  // Unless the inPersonURL is missing this will be ['review', 'prepare', 'location']
  const steps: FormStep[] = [reviewStep].concat(inPersonProofingSteps);
  if (flowPath !== 'hybrid') {
    return steps;
  }

  // When the user is in the hybrid flowPath, then they need to get the switch_back screen
  // after all of the other steps.
  if (flowPath === 'hybrid') {
    return steps.concat({
      name: 'switch_back',
      form: InPersonSwitchBackStep,
      title: t('in_person_proofing.headings.switch_back'),
    });
  }
};
