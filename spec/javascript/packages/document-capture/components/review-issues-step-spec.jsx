import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import {
  ServiceProviderContextProvider,
  AnalyticsContext,
  InPersonContext,
} from '@18f/identity-document-capture';
import { I18n } from '@18f/identity-i18n';
import { I18nContext } from '@18f/identity-react-i18n';
import ReviewIssuesStep from '@18f/identity-document-capture/components/review-issues-step';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/review-issues-step', () => {
  const DEFAULT_PROPS = { remainingAttempts: 3 };

  it('logs warning events', async () => {
    const trackEvent = sinon.spy();

    const { getByRole } = render(
      <AnalyticsContext.Provider value={{ trackEvent }}>
        <ReviewIssuesStep {...DEFAULT_PROPS} />
      </AnalyticsContext.Provider>,
    );

    expect(trackEvent).to.have.been.calledWith('IdV: warning shown', {
      location: 'doc_auth_review_issues',
      remaining_attempts: 3,
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
                one: 'One attempt remaining',
                other: '%{count} attempts remaining',
              },
            },
          })
        }
      >
        <ReviewIssuesStep {...DEFAULT_PROPS} />
      </I18nContext.Provider>,
    );

    expect(getByText('errors.doc_auth.throttled_heading')).to.be.ok();
    expect(getByText('3 attempts remaining')).to.be.ok();
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
          remainingAttempts={1}
          unknownFieldErrors={[
            {
              field: 'unknown',
              error: toFormEntryError({ field: 'unknown', message: 'An unknown error occurred' }),
            },
          ]}
        />
      </I18nContext.Provider>,
    );

    expect(getByText('errors.doc_auth.throttled_heading')).to.be.ok();
    expect(getByText('One attempt remaining')).to.be.ok();
    expect(getByText('An unknown error occurred')).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByText('An unknown error occurred')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
  });

  it('renders with front and back inputs', async () => {
    const { getByLabelText, getByRole } = render(<ReviewIssuesStep {...DEFAULT_PROPS} />);

    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText, getByRole } = render(
      <ReviewIssuesStep {...DEFAULT_PROPS} onChange={onChange} />,
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

  it('renders troubleshooting options', async () => {
    const { getByRole } = render(
      <ServiceProviderContextProvider
        value={{
          name: 'Example App',
          failureToProofURL: 'https://example.com/?step=document_capture',
        }}
      >
        <ReviewIssuesStep {...DEFAULT_PROPS} />
      </ServiceProviderContextProvider>,
    );

    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(
      getByRole('heading', { name: 'components.troubleshooting_options.default_heading' }),
    ).to.be.ok();
    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.get_help_at_sp links.new_tab' }).href,
    ).to.equal(
      'https://example.com/?step=document_capture&location=document_capture_troubleshooting_options',
    );
  });

  it('does not render sp help troubleshooting option for errored review', () => {
    const { queryByRole } = render(
      <InPersonContext.Provider value={{ inPersonURL: null }}>
        <ServiceProviderContextProvider
          value={{
            name: 'Example App',
            failureToProofURL: 'https://example.com/?step=document_capture',
          }}
        >
          <ReviewIssuesStep {...DEFAULT_PROPS} />
        </ServiceProviderContextProvider>
      </InPersonContext.Provider>,
    );

    expect(
      queryByRole('link', { name: 'idv.troubleshooting.options.get_help_at_sp links.new_tab' }),
    ).to.not.exist();
  });

  it('does render sp help troubleshooting option for errored review if in person url present', () => {
    const { getByRole } = render(
      <InPersonContext.Provider value={{ inPersonURL: 'http://example.com' }}>
        <ServiceProviderContextProvider
          value={{
            name: 'Example App',
            failureToProofURL: 'https://example.com/?step=document_capture',
          }}
        >
          <ReviewIssuesStep {...DEFAULT_PROPS} />
        </ServiceProviderContextProvider>
      </InPersonContext.Provider>,
    );

    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.get_help_at_sp links.new_tab' }).href,
    ).to.equal('https://example.com/?step=document_capture&location=post_submission_warning');
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
