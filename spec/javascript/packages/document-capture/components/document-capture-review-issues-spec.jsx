import { render, screen, within } from '@testing-library/react';
import DocumentCaptureReviewIssues from '@18f/identity-document-capture/components/document-capture-review-issues';
import { InPersonContext } from '@18f/identity-document-capture/context';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { expect } from 'chai';

describe('DocumentCaptureReviewIssues', () => {
  const DEFAULT_OPTIONS = {
    registerField: () => undefined,
    captureHints: true,
    remainingAttempts: 2,
    value: {},
    onChange: () => undefined,
    onError: () => undefined,
  };
  context('with doc error', () => {
    it('renders for non doc type failure', () => {
      const props = {
        isFailedDocType: false,
        unknownFieldErrors: [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
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
      };
      const { getByText, getByLabelText, getByRole, getAllByRole } = render(
        <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
          <DocumentCaptureReviewIssues
            {...{
              ...DEFAULT_OPTIONS,
              ...props,
            }}
          />
        </InPersonContext.Provider>,
      );
      const h1 = screen.getByRole('heading', { name: 'doc_auth.headings.review_issues', level: 1 });
      expect(h1).to.be.ok();

      expect(getByText('general error')).to.be.ok();

      // tips header
      expect(getByText('doc_auth.tips.review_issues_id_header_text')).to.be.ok();
      const lists = getAllByRole('list');
      const tipList = lists[0];
      expect(tipList).to.be.ok();
      const tipListItem = within(tipList).getAllByRole('listitem');
      tipListItem.forEach((li, idx) => {
        expect(li.textContent).to.equals(`doc_auth.tips.review_issues_id_text${idx + 1}`);
      });

      // front capture input
      const frontCapture = getByLabelText('doc_auth.headings.document_capture_front');
      expect(frontCapture).to.be.ok();
      expect(getByText('front side error')).to.be.ok();

      const backCapture = getByLabelText('doc_auth.headings.document_capture_back');
      expect(backCapture).to.be.ok();
      expect(getByText('back side error')).to.be.ok();
      const submitButton = getByRole('button');
      expect(submitButton).to.be.ok();
      expect(within(submitButton).getByText('forms.buttons.submit.default')).to.be.ok();
    });

    it('renders for a doc type failure', () => {
      const props = {
        isFailedDocType: true,
        unknownFieldErrors: [
          {
            field: 'general',
            error: toFormEntryError({ field: 'general', message: 'general error' }),
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
      };
      const { getByText, getByLabelText, getByRole } = render(
        <InPersonContext.Provider value={{ inPersonURL: '/verify/doc_capture' }}>
          <DocumentCaptureReviewIssues
            {...{
              ...DEFAULT_OPTIONS,
              ...props,
            }}
          />
        </InPersonContext.Provider>,
      );
      const h1 = screen.getByRole('heading', { name: 'doc_auth.headings.review_issues', level: 1 });
      expect(h1).to.be.ok();

      expect(getByText('doc_auth.errors.doc.wrong_id_type_html')).to.be.ok();

      // front capture input
      const frontCapture = getByLabelText('doc_auth.headings.document_capture_front');
      expect(frontCapture).to.be.ok();
      expect(getByText('front side doc type error')).to.be.ok();

      const backCapture = getByLabelText('doc_auth.headings.document_capture_back');
      expect(backCapture).to.be.ok();
      expect(getByText('back side doc type error')).to.be.ok();
      const submitButton = getByRole('button');
      expect(submitButton).to.be.ok();
      expect(within(submitButton).getByText('forms.buttons.submit.default')).to.be.ok();
    });
  });
});
