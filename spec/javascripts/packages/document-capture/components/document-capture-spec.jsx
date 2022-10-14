import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import httpUpload from '@18f/identity-document-capture/services/upload';
import {
  ServiceProviderContextProvider,
  UploadContextProvider,
  AcuantContextProvider,
  DeviceContext,
} from '@18f/identity-document-capture';
import DocumentCapture, {
  except,
} from '@18f/identity-document-capture/components/document-capture';
import { FlowContext } from '@18f/identity-verify-flow';
import { expect } from 'chai';
import { useSandbox } from '@18f/identity-test-helpers';
import { render, useAcuant, useDocumentCaptureForm } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/document-capture', () => {
  const onSubmit = useDocumentCaptureForm();
  const sandbox = useSandbox();
  const { initialize } = useAcuant();

  let originalHash;
  let validUpload;

  before(async () => {
    validUpload = await getFixtureFile('doc_auth_images/id-front.jpg');
  });

  beforeEach(() => {
    originalHash = window.location.hash;
  });

  afterEach(() => {
    window.location.hash = originalHash;
  });

  describe('except', () => {
    it('returns a new object without the specified keys', () => {
      const original = { a: 1, b: 2, c: 3, d: 4 };
      const result = except(original, 'b', 'c');

      expect(result).to.not.equal(original);
      expect(result).to.deep.equal({ a: 1, d: 4 });
    });
  });

  it('renders the form steps', () => {
    const { getByText } = render(<DocumentCapture />);

    const step = getByText('doc_auth.headings.document_capture_front');

    expect(step).to.be.ok();
  });

  it('shows top-level step errors', async () => {
    const { getByLabelText, findByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <DocumentCapture />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();
    // `onError` called with an Error instance is indication of camera access declined, which is
    // expected to show both field-level and step error.
    // See: https://github.com/18F/identity-idp/blob/164231d/app/javascript/packages/document-capture/components/acuant-capture.jsx#L114
    window.AcuantCameraUI.start.callsFake((_callbacks, onError) => onError(new Error()));

    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    await findByText('doc_auth.errors.camera.blocked_detail');
  });

  it('redirects from a server error', async () => {
    const endpoint = '/upload';
    const { getByLabelText, getByText } = render(
      <UploadContextProvider upload={httpUpload} endpoint={endpoint}>
        <ServiceProviderContextProvider value={{ isLivenessRequired: false }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <DocumentCapture />
          </AcuantContextProvider>
        </ServiceProviderContextProvider>
      </UploadContextProvider>,
    );

    sandbox
      .stub(window, 'fetch')
      .withArgs(endpoint)
      .resolves({
        ok: false,
        status: 418,
        url: endpoint,
        json: () =>
          Promise.resolve({
            redirect: '#teapot',
          }),
      });

    const frontImage = getByLabelText('doc_auth.headings.document_capture_front');
    const backImage = getByLabelText('doc_auth.headings.document_capture_back');
    await userEvent.upload(frontImage, validUpload);
    await userEvent.upload(backImage, validUpload);
    await waitFor(() => frontImage.src && backImage.src);

    await userEvent.click(getByText('forms.buttons.submit.default'));
    await waitFor(() => window.location.hash === '#teapot');

    // JSDOM doesn't support full page navigation, but at this point we should assume navigation
    // would have been initiated, meaning it's also safe to assume that the user would not expect
    // to see a "You have unsaved changed" prompt.
    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);
    expect(event.defaultPrevented).to.be.false();
  });

  describe('pending promise values', () => {
    let completeUploadAsSuccess;
    let completeUploadAsFailure;
    let renderResult;
    let upload;
    let submit;

    beforeEach(async () => {
      sandbox.stub(window, 'fetch');
      window.fetch.withArgs('about:blank#front').returns(
        new Promise((resolve, reject) => {
          completeUploadAsSuccess = () => resolve({ ok: true, headers: new window.Headers() });
          completeUploadAsFailure = () => reject(new Error());
        }),
      );
      window.fetch
        .withArgs('about:blank#back')
        .resolves({ ok: true, headers: new window.Headers() });
      upload = sinon.stub().resolves({ success: true, isPending: false });
      const key = await window.crypto.subtle.generateKey(
        {
          name: 'AES-GCM',
          length: 256,
        },
        true,
        ['encrypt', 'decrypt'],
      );
      renderResult = render(
        <UploadContextProvider
          endpoint="about:blank#upload"
          backgroundUploadURLs={{
            front: 'about:blank#front',
            back: 'about:blank#back',
          }}
          backgroundUploadEncryptKey={key}
          upload={upload}
        >
          <ServiceProviderContextProvider value={{ isLivenessRequired: false }}>
            <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
              <DocumentCapture />
            </AcuantContextProvider>
          </ServiceProviderContextProvider>
        </UploadContextProvider>,
      );
      const { getByLabelText, getByText } = renderResult;

      await userEvent.upload(
        getByLabelText('doc_auth.headings.document_capture_front'),
        validUpload,
      );
      await userEvent.upload(
        getByLabelText('doc_auth.headings.document_capture_back'),
        validUpload,
      );
      submit = () => userEvent.click(getByText('forms.buttons.submit.default'));
    });

    context('success', () => {
      it('calls to upload once pending values resolve', async () => {
        await submit();
        expect(upload).not.to.have.been.called();
        completeUploadAsSuccess();
        await new Promise((resolve) => onSubmit.callsFake(resolve));
        expect(upload).to.have.been.calledOnce();
      });
    });

    context('failure', () => {
      it('shows an error screen once pending values reject', async () => {
        await submit();
        expect(upload).not.to.have.been.called();
        completeUploadAsFailure();
        const { findAllByRole, getByLabelText } = renderResult;

        const alerts = (await findAllByRole('alert')).filter((alert) => alert.textContent);
        expect(alerts).to.have.lengthOf(2);
        expect(alerts[0].textContent).to.equal('doc_auth.errors.general.network_error');
        expect(alerts[1].textContent).to.equal(
          'doc_auth.errors.upload_error errors.messages.try_again',
        );

        const input = await getByLabelText('doc_auth.headings.document_capture_front');
        expect(input.closest('.usa-file-input--has-value')).to.be.null();

        expect(console).to.have.loggedError(/^Error: Uncaught/);
        expect(console).to.have.loggedError(
          /React will try to recreate this component tree from scratch using the error boundary you provided/,
        );

        expect(upload).not.to.have.been.called();
      });
    });
  });

  describe('step indicator', () => {
    it('renders the step indicator', () => {
      const { getByText } = render(<DocumentCapture />);

      const step = getByText('step_indicator.flows.idv.verify_id');

      expect(step).to.be.ok();
      expect(step.closest('.step-indicator__step--current')).to.exist();
    });

    context('in person steps', () => {
      it('renders the step indicator', async () => {
        const endpoint = '/upload';
        const { getByLabelText, getByText, findByText } = render(
          <UploadContextProvider upload={httpUpload} endpoint={endpoint}>
            <ServiceProviderContextProvider value={{ isLivenessRequired: false }}>
              <FlowContext.Provider
                value={{
                  cancelURL: '/cancel',
                  inPersonURL: '/in_person',
                  currentStep: 'document_capture',
                }}
              >
                <DocumentCapture />
              </FlowContext.Provider>
            </ServiceProviderContextProvider>
          </UploadContextProvider>,
        );

        sandbox
          .stub(window, 'fetch')
          .withArgs(endpoint)
          .resolves({
            ok: false,
            status: 400,
            url: endpoint,
            json: () => ({ success: false, remaining_attempts: 1, errors: [{}] }),
          });

        const frontImage = getByLabelText('doc_auth.headings.document_capture_front');
        const backImage = getByLabelText('doc_auth.headings.document_capture_back');
        await userEvent.upload(frontImage, validUpload);
        await userEvent.upload(backImage, validUpload);
        await waitFor(() => frontImage.src && backImage.src);

        await userEvent.click(getByText('forms.buttons.submit.default'));

        const verifyInPersonButton = await findByText(
          'idv.troubleshooting.options.verify_in_person',
        );
        await userEvent.click(verifyInPersonButton);

        expect(console).to.have.loggedError(/^Error: Uncaught/);
        expect(console).to.have.loggedError(
          /React will try to recreate this component tree from scratch using the error boundary you provided/,
        );

        const step = await findByText('step_indicator.flows.idv.find_a_post_office');

        expect(step).to.be.ok();
        expect(step.closest('.step-indicator__step--current')).to.exist();
      });
    });
  });
});
