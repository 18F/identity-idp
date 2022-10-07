import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import {
  ServiceProviderContextProvider,
  UploadContextProvider,
  AnalyticsContext,
} from '@18f/identity-document-capture';
import ReviewIssuesStep from '@18f/identity-document-capture/components/review-issues-step';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { useSandbox } from '@18f/identity-test-helpers';
import { render } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/review-issues-step', () => {
  const DEFAULT_PROPS = { remainingAttempts: 3 };
  const sandbox = useSandbox();

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
    const { getByRole, getByText } = render(<ReviewIssuesStep {...DEFAULT_PROPS} />);

    expect(getByText('errors.doc_auth.throttled_heading')).to.be.ok();
    expect(getByText('idv.failure.attempts.other')).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

    expect(
      getByRole('link', { name: 'idv.troubleshooting.options.doc_capture_tips links.new_window' }),
    ).to.exist();
    expect(
      getByRole('link', {
        name: 'idv.troubleshooting.options.supported_documents links.new_window',
      }),
    ).to.exist();
  });

  it('renders warning page with error and displays one attempt remaining then continues on', async () => {
    const { getByRole, getByLabelText, getByText } = render(
      <ReviewIssuesStep
        remainingAttempts={1}
        unknownFieldErrors={[
          {
            field: 'unknown',
            error: toFormEntryError({ field: 'unknown', message: 'An unknown error occurred' }),
          },
        ]}
      />,
    );

    expect(getByText('errors.doc_auth.throttled_heading')).to.be.ok();
    expect(getByText('idv.failure.attempts.one')).to.be.ok();
    expect(getByText('An unknown error occurred')).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();

    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByText('An unknown error occurred')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
  });

  it('renders with front, back, and selfie inputs', async () => {
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

  it('performs background encrypted uploads', async () => {
    const onChange = sandbox.stub();
    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve({
        ok: true,
        status: 200,
        headers: new window.Headers(),
      }),
    );
    const key = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );
    const { getByLabelText, getByRole } = render(
      <UploadContextProvider
        backgroundUploadURLs={{ back: 'about:blank#back' }}
        backgroundUploadEncryptKey={key}
      >
        <ReviewIssuesStep {...DEFAULT_PROPS} onChange={onChange} />)
      </UploadContextProvider>,
    );

    const file = await getFixtureFile('doc_auth_images/id-back.jpg');
    await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    await Promise.all([
      new Promise((resolve) => onChange.callsFake(resolve)),
      userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), file),
    ]);
    const patch = onChange.getCall(0).args[0];
    expect(await patch.back_image_url).to.equal('about:blank#back');
    expect(window.fetch.getCall(0).args[0]).to.equal('about:blank#back');
  });

  it('renders troubleshooting options', async () => {
    const { getByRole } = render(
      <ServiceProviderContextProvider
        value={{
          name: 'Example App',
          failureToProofURL: 'https://example.com/?step=document_capture',
          isLivenessRequired: false,
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
      getByRole('link', { name: 'idv.troubleshooting.options.get_help_at_sp links.new_window' })
        .href,
    ).to.equal(
      'https://example.com/?step=document_capture&location=document_capture_troubleshooting_options',
    );
  });

  context('service provider context', () => {
    context('ial2', () => {
      it('renders with front and back inputs', async () => {
        const { getByLabelText, getByRole } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: false,
            }}
          >
            <ReviewIssuesStep {...DEFAULT_PROPS} />
          </ServiceProviderContextProvider>,
        );
        await userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
        expect(() => getByLabelText('doc_auth.headings.document_capture_selfie')).to.throw();
      });
    });

    context('ial2 strict', () => {
      it('renders with front, back, and selfie inputs', async () => {
        const { getByLabelText, getByRole } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: true,
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
