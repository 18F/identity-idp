import userEvent from '@testing-library/user-event';
import sinon from 'sinon';
import {
  ServiceProviderContextProvider,
  UploadContextProvider,
} from '@18f/identity-document-capture';
import ReviewIssuesStep, {
  reviewIssuesStepValidator,
} from '@18f/identity-document-capture/components/review-issues-step';
import { toFormEntryError } from '@18f/identity-document-capture/services/upload';
import { render } from '../../../support/document-capture';
import { useSandbox } from '../../../support/sinon';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/review-issues-step', () => {
  const sandbox = useSandbox();

  describe('reviewIssuesStepValidator', () => {
    it('returns false if given undefined value', () => {
      const isValid = reviewIssuesStepValidator();

      expect(isValid).to.be.false();
    });

    it('returns false if either of front or back are absent', () => {
      for (const key of ['front', 'back']) {
        const isValid = reviewIssuesStepValidator({ [key]: new window.Blob() });

        expect(isValid).to.be.false();
      }
    });

    it('returns true if front and back are given, and selfie is not applicable', () => {
      const isValid = reviewIssuesStepValidator({
        front: new window.Blob(),
        back: new window.Blob(),
      });

      expect(isValid).to.be.true();
    });

    it('returns false if selfie is applicable and missing', () => {
      const isValid = reviewIssuesStepValidator({
        front: new window.Blob(),
        back: new window.Blob(),
        selfie: null,
      });

      expect(isValid).to.be.false();
    });

    it('returns true if selfie is applicable and given', () => {
      const isValid = reviewIssuesStepValidator({
        front: new window.Blob(),
        back: new window.Blob(),
        selfie: new window.Blob(),
      });

      expect(isValid).to.be.true();
    });
  });

  it('renders initially with warning page and displays attempts remaining', () => {
    const { getByRole, getByText } = render(<ReviewIssuesStep remainingAttempts={3} />);

    expect(getByText('errors.doc_auth.throttled_heading')).to.be.ok();
    expect(getByText('idv.failure.attempts.other')).to.be.ok();
    expect(getByRole('button', { name: 'idv.failure.button.warning' })).to.be.ok();
  });

  it('renders warning page with error and displays one attempt remaining then continues on', () => {
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

    userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByText('An unknown error occurred')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
  });

  it('renders with front, back, and selfie inputs', () => {
    const { getByLabelText, getByRole } = render(<ReviewIssuesStep />);

    userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
    expect(getByLabelText('doc_auth.headings.document_capture_selfie')).to.be.ok();
  });

  it('calls onChange callback with uploaded image', async () => {
    const onChange = sinon.stub();
    const { getByLabelText, getByRole } = render(<ReviewIssuesStep onChange={onChange} />);
    const file = await getFixtureFile('doc_auth_images/id-back.jpg');
    userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), file);
    await new Promise((resolve) => onChange.callsFake(resolve));
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
        <ReviewIssuesStep onChange={onChange} />)
      </UploadContextProvider>,
    );

    const file = await getFixtureFile('doc_auth_images/id-back.jpg');
    userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), file);
    await new Promise((resolve) => onChange.callsFake(resolve));
    const patch = onChange.getCall(0).args[0];
    expect(await patch.back_image_url).to.equal('about:blank#back');
    expect(window.fetch.getCall(0).args[0]).to.equal('about:blank#back');
  });

  it('renders troubleshooting options', () => {
    const { getByRole } = render(
      <ServiceProviderContextProvider
        value={{
          name: 'Example App',
          failureToProofURL: 'https://example.com/?step=document_capture',
          isLivenessRequired: false,
        }}
      >
        <ReviewIssuesStep />
      </ServiceProviderContextProvider>,
    );

    userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

    expect(
      getByRole('heading', { name: 'idv.troubleshooting.headings.having_trouble' }),
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
      it('renders with front and back inputs', () => {
        const { getByLabelText, getByRole } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: false,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContextProvider>,
        );
        userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
        expect(() => getByLabelText('doc_auth.headings.document_capture_selfie')).to.throw();
      });
    });

    context('ial2 strict', () => {
      it('renders with front, back, and selfie inputs', () => {
        const { getByLabelText, getByRole } = render(
          <ServiceProviderContextProvider
            value={{
              name: 'Example App',
              failureToProofURL: 'https://example.com',
              isLivenessRequired: true,
            }}
          >
            <ReviewIssuesStep />
          </ServiceProviderContextProvider>,
        );
        userEvent.click(getByRole('button', { name: 'idv.failure.button.warning' }));

        expect(getByLabelText('doc_auth.headings.document_capture_front')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_back')).to.be.ok();
        expect(getByLabelText('doc_auth.headings.document_capture_selfie')).to.be.ok();
      });
    });
  });
});
