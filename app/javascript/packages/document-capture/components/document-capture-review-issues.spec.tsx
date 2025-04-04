import { render, screen } from '@testing-library/react';
import DocumentCaptureReviewIssues from '@18f/identity-document-capture/components/document-capture-review-issues';
import { InPersonContext } from '@18f/identity-document-capture/context';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { I18nContext } from '@18f/identity-react-i18n';
import { I18n } from '@18f/identity-i18n';
import { expect } from 'chai';

describe('DocumentCaptureReviewIssues', () => {
  const DEFAULT_OPTIONS = {
    registerField: () => undefined,
    value: {},
    onChange: () => undefined,
    onError: () => undefined,
    isFailedSelfie: false,
    isFailedDocType: false,
    isFailedSelfieLivenessOrQuality: false,
    remainingSubmitAttempts: Infinity,
    unknownFieldErrors: [],
    errors: [],
    hasDismissed: false,
    toPreviousStep: () => undefined,
  };

  context('with default props', () => {
    it('does not display infinity remaining attempts', () => {
      const { queryByText } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'idv.failure.attempts_html': 'You have %{count} attempts remaining.',
              },
            })
          }
        >
          <DocumentCaptureReviewIssues {...DEFAULT_OPTIONS} />
        </I18nContext.Provider>,
      );

      expect(queryByText('You have Infinity attempts remaining.')).to.equal(null);
    });
  });

  context('with doc error', () => {
    it('renders for non doc type failure', () => {
      const { getByText, getByLabelText, getByRole } = render(
        <InPersonContext.Provider
          value={{
            inPersonURL: '/verify/doc_capture',
            locationsURL: '',
            inPersonOutageMessageEnabled: false,
            optedInToInPersonProofing: false,
            passportEnabled: false,
            usStatesTerritories: [['Los Angeles', 'NY']],
          }}
        >
          <I18nContext.Provider
            value={
              new I18n({
                strings: { 'idv.failure.attempts_html': 'You have %{count} attempts remaining.' },
              })
            }
          >
            <DocumentCaptureReviewIssues
              {...{
                ...DEFAULT_OPTIONS,
                isFailedDocType: false,
                remainingSubmitAttempts: 2,
                unknownFieldErrors: [
                  {
                    error: toFormEntryError({ field: 'network', message: 'general error' }),
                  },
                ],
                errors: [
                  {
                    field: 'front',
                    error: toFormEntryError({ field: 'front', message: 'front side error' }),
                  },
                  {
                    field: 'back',
                    error: toFormEntryError({ field: 'back', message: 'back side error' }),
                  },
                ],
              }}
            />
          </I18nContext.Provider>
        </InPersonContext.Provider>,
      );

      const h1 = screen.getByRole('heading', { name: 'doc_auth.headings.review_issues', level: 1 });
      expect(h1).to.be.ok();

      expect(getByText('general error')).to.be.ok();

      expect(getByText('You have 2 attempts remaining.')).to.be.ok();

      // front capture input
      const frontCapture = getByLabelText('doc_auth.headings.document_capture_front');
      expect(frontCapture).to.be.ok();
      expect(getByText('front side error')).to.be.ok();

      const backCapture = getByLabelText('doc_auth.headings.document_capture_back');
      expect(backCapture).to.be.ok();
      expect(getByText('back side error')).to.be.ok();
      expect(getByRole('button', { name: 'forms.buttons.submit.default' })).to.be.ok();
    });

    it('renders for a doc type failure', () => {
      const { getByText, getByLabelText, getByRole } = render(
        <InPersonContext.Provider
          value={{
            inPersonURL: '/verify/doc_capture',
            locationsURL: '',
            inPersonOutageMessageEnabled: false,
            optedInToInPersonProofing: false,
            passportEnabled: false,
            usStatesTerritories: [['Los Angeles', 'NY']],
          }}
        >
          <DocumentCaptureReviewIssues
            {...{
              ...DEFAULT_OPTIONS,
              isFailedDocType: true,
              unknownFieldErrors: [
                {
                  error: toFormEntryError({ field: 'network', message: 'general error' }),
                },
              ],
              errors: [
                {
                  field: 'front',
                  error: toFormEntryError({ field: 'front', message: 'front side doc type error' }),
                },
                {
                  field: 'back',
                  error: toFormEntryError({ field: 'back', message: 'back side doc type error' }),
                },
              ],
            }}
          />
        </InPersonContext.Provider>,
      );
      const h1 = screen.getByRole('heading', { name: 'doc_auth.headings.review_issues', level: 1 });
      expect(h1).to.be.ok();

      expect(getByText('doc_auth.errors.doc.doc_type_check')).to.be.ok();

      // front capture input
      const frontCapture = getByLabelText('doc_auth.headings.document_capture_front');
      expect(frontCapture).to.be.ok();
      expect(getByText('front side doc type error')).to.be.ok();

      const backCapture = getByLabelText('doc_auth.headings.document_capture_back');
      expect(backCapture).to.be.ok();
      expect(getByText('back side doc type error')).to.be.ok();
      expect(getByRole('button', { name: 'forms.buttons.submit.default' })).to.be.ok();
    });
  });
});
