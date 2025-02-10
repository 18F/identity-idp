import sinon from 'sinon';
import { AnalyticsContext } from '@18f/identity-document-capture';
import { render, screen, within } from '@testing-library/react';
import { InPersonContext } from '@18f/identity-document-capture/context';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { expect } from 'chai';
import DocumentCaptureWarning from '@18f/identity-document-capture/components/document-capture-warning';

describe('DocumentCaptureWarning', () => {
  const trackEvent = sinon.spy();

  function validateHeader(headerName, level, existing) {
    const h = screen.queryByRole('heading', {
      name: headerName,
      level,
    });
    if (existing) {
      expect(h).to.be.ok();
    } else {
      expect(h).to.be.null();
    }
  }

  function validateTroubleShootingSection() {
    validateHeader('components.troubleshooting_options.ipp_heading', 2, true);
    /* list of troubleshooting links */
    const troubleShootingList = screen.getByRole('list');
    expect(troubleShootingList).to.be.ok();
    const troubleShootingListItem = within(troubleShootingList).getAllByRole('listitem');
    expect(troubleShootingListItem).to.be.ok();
    const hrefLinks = within(troubleShootingList).getAllByRole('link');
    hrefLinks.forEach((hrefLink) => {
      expect(hrefLink.href).to.contains('location=post_submission_warning');
      expect(hrefLink.href).to.contains('article=');
    });
  }

  function validateIppSection(existing) {
    validateHeader('in_person_proofing.headings.cta', 2, existing);
    /* ipp prompt */
    const prompt = screen.queryByText('in_person_proofing.body.cta.prompt_detail');
    if (existing) {
      expect(prompt).to.be.ok();
      expect(screen.getByRole('button', { name: 'in_person_proofing.body.cta.button' })).to.be.ok();
    } else {
      expect(prompt).to.be.null();
    }
  }

  function renderContent({
    isFailedDocType,
    isFailedResult,
    isFailedSelfieLivenessOrQuality = false,
    isFailedSelfieFaceMatch = false,
    inPersonUrl,
  }) {
    const unknownFieldErrors = [
      {
        field: 'general',
        error: toFormEntryError({ field: 'general', message: 'general error' }),
      },
    ];
    return render(
      <AnalyticsContext.Provider value={{ trackEvent }}>
        <InPersonContext.Provider value={{ inPersonURL: inPersonUrl }}>
          <DocumentCaptureWarning
            isFailedDocType={isFailedDocType}
            isFailedResult={isFailedResult}
            isFailedSelfie={isFailedSelfieFaceMatch}
            isFailedSelfieLivenessOrQuality={isFailedSelfieLivenessOrQuality}
            remainingSubmitAttempts={2}
            unknownFieldErrors={unknownFieldErrors}
            actionOnClick={() => {}}
          />
          ,
        </InPersonContext.Provider>
      </AnalyticsContext.Provider>,
    );
  }

  context('ipp ', () => {
    const inPersonUrl = '/verify/doc_capture';

    it('logs the warning displayed to the user', () => {
      const isFailedResult = false;
      const isFailedDocType = false;

      renderContent({ isFailedDocType, isFailedResult, inPersonUrl });

      expect(trackEvent).to.have.been.calledWith('IdV: warning shown', {
        location: 'doc_auth_review_issues',
        heading: 'doc_auth.errors.rate_limited_heading',
        subheading: 'doc_auth.errors.rate_limited_subheading',
        error_message_displayed: 'general error',
        remaining_submit_attempts: 2,
        liveness_checking_required: false,
      });
    });

    context('not failed result from vendor', () => {
      const isFailedResult = false;
      it('renders not failed doc type', () => {
        const { getByRole, getByText } = renderContent({
          isFailedDocType: false,
          isFailedResult,
          inPersonUrl,
        });

        validateHeader('doc_auth.errors.rate_limited_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, true);
        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();
        // ipp section
        validateIppSection(true);
        // troubleshooting section
        validateTroubleShootingSection();
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const { getByRole, getByText, queryByText } = renderContent({
          isFailedDocType,
          isFailedResult,
          inPersonUrl,
        });
        // error message section
        validateHeader('doc_auth.errors.doc_type_not_supported_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, true);
        expect(getByText(/general error/)).to.be.ok();
        expect(queryByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();
        // ipp section
        validateIppSection(true);
        // troubleshooting section
        validateTroubleShootingSection();
      });
    });

    context('failed result from vendor', () => {
      const isFailedResult = true;
      it('renders not failed doc type', () => {
        const isFailedDocType = false;
        const { getByRole, getByText } = renderContent({
          isFailedDocType,
          isFailedResult,
          inPersonUrl,
        });

        // error message section
        validateHeader('doc_auth.errors.rate_limited_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, false);
        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
        // troubleshooting section
        validateTroubleShootingSection();
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const { getByRole, getByText, queryByText } = renderContent({
          isFailedDocType,
          isFailedResult,
          inPersonUrl,
        });

        // error message section
        validateHeader('doc_auth.errors.doc_type_not_supported_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, false);
        expect(getByText(/general error/)).to.be.ok();
        expect(queryByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
        // troubleshooting section
        validateTroubleShootingSection();
      });
    });

    it('renders with failed facematch for selfie', () => {
      const isFailedDocType = false;
      const isFailedResult = false;
      const isFailedSelfieFaceMatch = true;
      const { getByRole, getByText, queryByText } = renderContent({
        isFailedDocType,
        isFailedSelfieFaceMatch,
        isFailedResult,
        inPersonUrl,
      });

      // error message section
      validateHeader('doc_auth.errors.selfie_fail_heading', 1, true);
      validateHeader('doc_auth.errors.rate_limited_subheading', 2, true);
      expect(getByText('general error')).to.be.ok();
      expect(queryByText('idv.failure.attempts_html')).to.be.ok();
      expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();
      // ipp section should exist
      validateIppSection(true);
      // troubleshooting section
      validateTroubleShootingSection();
    });

    it('renders with failed quality/liveness selfie', () => {
      const isFailedDocType = false;
      const isFailedResult = false;
      const isFailedSelfieLivenessOrQuality = true;
      const { getByRole, getByText, queryByText } = renderContent({
        isFailedDocType,
        isFailedSelfieLivenessOrQuality,
        isFailedResult,
        inPersonUrl,
      });

      // error message section
      validateHeader('doc_auth.errors.selfie_not_live_or_poor_quality_heading', 1, true);
      validateHeader('doc_auth.errors.rate_limited_subheading', 2, true);
      expect(getByText('general error')).to.be.ok();
      expect(queryByText('idv.failure.attempts_html')).to.be.ok();
      expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();
      // ipp section exists
      validateIppSection(true);
      // troubleshooting section
      validateTroubleShootingSection();
    });
  });

  context('non ipp ', () => {
    const inPersonUrl = '';

    it('logs the warning displayed to the user', () => {
      const isFailedResult = true;
      const isFailedDocType = true;

      renderContent({ isFailedDocType, isFailedResult, inPersonUrl });

      expect(trackEvent).to.have.been.calledWith('IdV: warning shown', {
        location: 'doc_auth_review_issues',
        heading: 'doc_auth.errors.doc_type_not_supported_heading',
        subheading: '',
        error_message_displayed: 'general error',
        remaining_submit_attempts: 2,
        liveness_checking_required: false,
      });
    });

    context('not failed result', () => {
      const isFailedResult = false;
      it('renders not failed doc type', () => {
        const isFailedDocType = false;
        const { getByRole, getByText } = renderContent({
          isFailedDocType,
          isFailedResult,
          inPersonUrl,
        });

        // error message section
        validateHeader('doc_auth.errors.rate_limited_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, false);
        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
        // ipp section not displayed for non ipp
        validateIppSection(false);
        // troubleshooting section
        validateTroubleShootingSection();
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const { getByRole, getByText, queryByText } = renderContent({
          isFailedDocType,
          isFailedResult,
          inPersonUrl,
        });

        // error message section
        validateHeader('doc_auth.errors.doc_type_not_supported_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, false);
        expect(getByText(/general error/)).to.be.ok();
        expect(queryByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
        // ipp section not displayed for non ipp
        validateIppSection(false);
        // troubleshooting section
        validateTroubleShootingSection();
      });
    });

    context('failed result', () => {
      const isFailedResult = true;
      it('renders not failed doc type', () => {
        const isFailedDocType = false;
        const { getByRole, getByText } = renderContent({
          isFailedDocType,
          isFailedResult,
          inPersonUrl,
        });

        // error message section
        validateHeader('doc_auth.errors.rate_limited_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, false);
        expect(getByText('general error')).to.be.ok();
        expect(getByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
        // the ipp section isn't displayed with isFailedResult=true
        validateIppSection(false);
        // troubleshooting section
        validateTroubleShootingSection();
      });

      it('renders with failed doc type', () => {
        const isFailedDocType = true;
        const { getByRole, getByText, queryByText } = renderContent({
          isFailedDocType,
          isFailedResult,
          inPersonUrl,
        });
        // error message section
        validateHeader('doc_auth.errors.doc_type_not_supported_heading', 1, true);
        validateHeader('doc_auth.errors.rate_limited_subheading', 2, false);
        expect(getByText(/general error/)).to.be.ok();
        expect(queryByText('idv.failure.attempts_html')).to.be.ok();
        expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
        // ipp section not existing
        validateIppSection(false);
        // troubleshooting section
        validateTroubleShootingSection();
      });
    });
  });
});
