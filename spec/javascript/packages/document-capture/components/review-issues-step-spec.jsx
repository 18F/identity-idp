import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import {
  ServiceProviderContextProvider,
  AnalyticsContext,
  InPersonContext,
  FailedCaptureAttemptsContextProvider,
  SelfieCaptureContext,
} from '@18f/identity-document-capture';
import { I18n } from '@18f/identity-i18n';
import { I18nContext } from '@18f/identity-react-i18n';
import ReviewIssuesStep from '@18f/identity-document-capture/components/review-issues-step';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/review-issues-step', () => {
  const DEFAULT_PROPS = {
    remainingSubmitAttempts: 3,
    unknownFieldErrors: [
      {
        field: 'general',
        error: toFormEntryError({ field: 'general', message: 'test error' }),
      },
    ],
  };

  it('logs warning events', async () => {
    const trackEvent = sinon.spy();

    const { getByRole } = render(
      <I18nContext.Provider
        value={
          new I18n({
            strings: {
              'doc_auth.errors.rate_limited_heading': 'We couldn’t verify your ID',
            },
          })
        }
      >
        <AnalyticsContext.Provider value={{ trackEvent }}>
          <ReviewIssuesStep {...DEFAULT_PROPS} />
        </AnalyticsContext.Provider>
      </I18nContext.Provider>,
    );

    expect(trackEvent).to.have.been.calledWith('IdV: warning shown', {
      location: 'doc_auth_review_issues',
      remaining_submit_attempts: 3,
      heading: 'We couldn’t verify your ID',
      subheading: '',
      error_message_displayed: 'test error',
      liveness_checking_required: false,
    });

    const button = getByRole('button');
    await userEvent.click(button);

    expect(trackEvent).to.have.been.calledWith('IdV: warning action triggered', {
      location: 'doc_auth_review_issues',
    });
  });

  it('renders initially with warning page and displays attempts remaining', () => {
    const { getByRole, getByText } = render(
      <I18nContext.Provider
        value={
          new I18n({
            strings: {
              'idv.failure.attempts_html': {
                one: '<strong>One attempt</strong> remaining',
                other: '<strong>%{count} attempts</strong> remaining',
              },
            },
          })
        }
      >
        <ReviewIssuesStep {...DEFAULT_PROPS} />
      </I18nContext.Provider>,
    );

    expect(getByText('doc_auth.errors.rate_limited_heading')).to.be.ok();
    expect(getByText('3 attempts', { selector: 'strong' })).to.be.ok();
    expect(getByText('remaining')).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.doc_capture_tips links.new_tab' }),
    ).to.exist();
    expect(
      getByRole('link', {
        name: 'idv.troubleshooting.options.supported_documents links.new_tab',
      }),
    ).to.exist();
  });
  it('renders initially with warning page and displays attempts remaining with IPP', () => {
    const { getByRole, getByText } = render(
      <InPersonContext.Provider value={{ inPersonURL: '/' }}>
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'idv.failure.attempts_html': {
                  one: '<strong>One attempt</strong> remaining',
                  other: '<strong>%{count} attempts</strong> remaining',
                },
              },
            })
          }
        >
          <ReviewIssuesStep {...DEFAULT_PROPS} />
        </I18nContext.Provider>
      </InPersonContext.Provider>,
    );

    expect(getByText('doc_auth.errors.rate_limited_heading')).to.be.ok();
    expect(getByText('3 attempts', { selector: 'strong' })).to.be.ok();
    expect(getByText('remaining')).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();
    expect(getByRole('button', { name: 'in_person_proofing.body.cta.button' })).to.be.ok();

    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.doc_capture_tips links.new_tab' }),
    ).to.exist();
    expect(
      getByRole('link', {
        name: 'idv.troubleshooting.options.supported_documents links.new_tab',
      }),
    ).to.exist();
  });

  it('renders warning page with error and displays one attempt remaining then continues on', async () => {
    const { getByRole, getByLabelText, getByText } = render(
      <I18nContext.Provider
        value={
          new I18n({
            strings: {
              'idv.failure.attempts_html': {
                one: 'One attempt remaining',
                other: '%{count} attempts remaining',
              },
            },
          })
        }
      >
        <ReviewIssuesStep
          remainingSubmitAttempts={1}
          unknownFieldErrors={[
            {
              field: 'unknown',
              error: toFormEntryError({ field: 'unknown', message: 'An unknown error occurred' }),
            },
          ]}
        />
      </I18nContext.Provider>,
    );

    expect(getByText('doc_auth.errors.rate_limited_heading')).to.be.ok();
    expect(getByText('One attempt remaining')).to.be.ok();
    expect(getByText('An unknown error occurred')).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByText('An unknown error occurred')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
  });

  it('renders with only front and back inputs only by default', async () => {
    const { getByLabelText, queryByLabelText, getByRole } = render(
      <ReviewIssuesStep {...DEFAULT_PROPS} />,
    );

    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
    expect(queryByLabelText('doc_auth.headings.document_capture_selfie')).to.not.exist();
  });

  it('renders with front, back, and selfie inputs when isSelfieCaptureEnabled is true', async () => {
    const { getByLabelText, queryByLabelText, getByRole } = render(
      <SelfieCaptureContext.Provider value={{ isSelfieCaptureEnabled: true }}>
        <ReviewIssuesStep {...DEFAULT_PROPS} />
      </SelfieCaptureContext.Provider>,
    );

    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
    expect(queryByLabelText('doc_auth.headings.document_capture_selfie')).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText, getByRole } = render(
      <FailedCaptureAttemptsContextProvider
        maxCaptureAttemptsBeforeNativeCamera={3}
        maxSubmissionAttemptsBeforeNativeCamera={3}
      >
        <ReviewIssuesStep {...DEFAULT_PROPS} onChange={onChange} />,
      </FailedCaptureAttemptsContextProvider>,
    );
    const file = await getFixtureFile('doc_auth_images/id-back.jpg');
    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    await Promise.all([
      new Promise((resolve) => onChange.callsFake(resolve)),
      userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file),
    ]);
    expect(onChange).to.have.been.calledWith({
      front: file,
      front_image_metadata: sinon.match(/^\{.+\}$/),
    });
  });

  it('renders alternative error messages with in person and doc type is not supported', async () => {
    const { getByRole, getByText, getByLabelText } = render(
      <InPersonContext.Provider value={{ inPersonURL: 'http://example.com' }}>
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'idv.failure.attempts_html': {
                  one: '<strong>One attempt</strong> remaining to add your ID online',
                  other: '<strong>%{count} attempts</strong> remaining to add your ID online',
                },
                'doc_auth.errors.rate_limited_heading': 'We couldn’t verify your ID',
                'doc_auth.errors.doc.doc_type_check':
                  'Your ID must be issued by the U.S. government or a U.S. state or territory. We do not accept military IDs.',
              },
            })
          }
        >
          <ReviewIssuesStep
            isFailedDocType
            remainingSubmitAttempts={3}
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'gerneral', message: 'only state id' }),
              },
            ]}
          />
        </I18nContext.Provider>
        ,
      </InPersonContext.Provider>,
    );
    expect(getByText('doc type not supported')).to.be.ok();
    expect(getByText(/3 attempts/, { selector: 'strong' })).to.be.ok();
    expect(getByText(/only state id/)).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.try_online' })).to.be.ok();
    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.doc_capture_tips links.new_tab' }),
    ).to.exist();
    expect(
      getByRole('link', {
        name: 'idv.troubleshooting.options.supported_documents links.new_tab',
      }),
    ).to.exist();

    // click try again
    await userEvent.click(getByRole('button', { name: 'idv.failure.button.try_online' }));
    // now use the alternative error message
    expect(
      getByText("We only accept a driver's license or a state ID card at this time."),
    ).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
  });

  it('renders alternative error messages with not in person and doc type is not supported', async () => {
    const { getByRole, getByText, getByLabelText } = render(
      <InPersonContext.Provider value={{ inPersonURL: '' }}>
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'idv.failure.attempts_html': {
                  one: '<strong>One attempt</strong> remaining to add your ID online',
                  other: '<strong>%{count} attempts</strong> remaining to add your ID online',
                },
                'doc_auth.errors.rate_limited_heading': 'We couldn’t verify your ID',
                'doc_auth.errors.doc.doc_type_check':
                  'Your ID must be issued by the U.S. government or a U.S. state or territory. We do not accept military IDs.',
              },
            })
          }
        >
          <ReviewIssuesStep
            isFailedDocType
            remainingSubmitAttempts={3}
            unknownFieldErrors={[
              {
                field: 'general',
                error: toFormEntryError({ field: 'gerneral', message: 'only state id' }),
              },
            ]}
          />
        </I18nContext.Provider>
        ,
      </InPersonContext.Provider>,
    );
    expect(getByText('doc type not supported')).to.be.ok();
    expect(getByText(/3 attempts/, { selector: 'strong' })).to.be.ok();
    expect(getByText(/only state id/)).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.doc_capture_tips links.new_tab' }),
    ).to.exist();
    expect(
      getByRole('link', {
        name: 'idv.troubleshooting.options.supported_documents links.new_tab',
      }),
    ).to.exist();

    // click try again
    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));
    expect(
      getByText("We only accept a driver's license or a state ID card at this time."),
    ).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
  });

  context('service provider context', () => {
    context('ial2', () => {
      it('renders with front and back inputs', async () => {
        const { getByLabelText, getByRole } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
            }}
          >
            <ReviewIssuesStep {...DEFAULT_PROPS} />
          </ServiceProviderContextProvider>,
        );
        await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
      });
    });

    it('skip renders initially with warning page when failed image is submitted again', () => {
      const { queryByRole, getByRole, getByText } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'idv.failure.attempts_html': {
                  one: '<strong>One attempt</strong> remaining',
                  other: '<strong>%{count} attempts</strong> remaining',
                },
              },
            })
          }
        >
          <FailedCaptureAttemptsContextProvider
            failedFingerprints={{ front: ['12345'], back: [] }}
            maxCaptureAttemptsBeforeNativeCamera={3}
            maxSubmissionAttemptsBeforeNativeCamera={3}
          >
            <ReviewIssuesStep
              value={{ front_image_metadata: '{ "fingerprint": "12345" }' }}
              {...DEFAULT_PROPS}
              failedImageFingerprints={{ front: ['12345'], back: [] }}
              errors={[
                {
                  field: 'front',
                  error: toFormEntryError({
                    field: 'front',
                    message: 'duplicate image',
                    type: 'duplicate_image',
                  }),
                },
              ]}
            />
          </FailedCaptureAttemptsContextProvider>
        </I18nContext.Provider>,
      );

      expect(queryByRole('button', { name: 'idv.failure.button.warning' })).to.not.exist();
      expect(getByRole('heading', { name: 'doc_auth.headings.review_issues' })).to.be.ok();
      expect(getByText('duplicate image')).to.be.ok();
    });

    context('ial2 strict', () => {
      it('renders with front and back inputs', async () => {
        const { getByLabelText, getByRole } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
            }}
          >
            <ReviewIssuesStep {...DEFAULT_PROPS} />
          </ServiceProviderContextProvider>,
        );
        await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
      });
    });
  });

  context('with barcode attention error', () => {
    it('renders initially with warning page', () => {
      async () => {
        const { getByRole, getByText } = render(
          <ReviewIssuesStep
            pii={{ first_name: 'Fakey', last_name: 'McFakerson', dob: '1938-10-06' }}
          />,
        );

        expect(getByText('doc_auth.errors.barcode_attention.heading')).to.be.ok();

        await userEvent.click(getByRole('button', { name: 'doc_auth.buttons.add_new_photos' }));

        expect(getByText('doc_auth.headings.review_issues')).to.be.ok();
      };
    });
  });
});
