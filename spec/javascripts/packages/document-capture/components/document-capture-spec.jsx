import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import { render as baseRender, fireEvent, cleanup } from '@testing-library/react';
import httpUpload, {
  UploadFormEntriesError,
  toFormEntryError,
} from '@18f/identity-document-capture/services/upload';
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
import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import { render, useAcuant, useDocumentCaptureForm } from '../../../support/document-capture';
import { getFixture, getFixtureFile } from '../../../support/file';

describe('document-capture/components/document-capture', () => {
  const onSubmit = useDocumentCaptureForm();
  const defineProperty = useDefineProperty();
  const sandbox = useSandbox();
  const { initialize } = useAcuant();

  function isFormValid(form) {
    return [...form.querySelectorAll('input')].every((input) => input.checkValidity());
  }

  let originalHash;
  let validUpload;
  let validSelfieBase64;

  before(async () => {
    validUpload = await getFixtureFile('doc_auth_images/id-front.jpg');
    validSelfieBase64 = await getFixture('doc_auth_images/selfie.jpg', 'base64');
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

  it('progresses through steps to completion', async () => {
    const { getByLabelText, getByText, getAllByText, findAllByText } = render(
      <DeviceContext.Provider value={{ isMobile: true }}>
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <DocumentCapture />
        </AcuantContextProvider>
      </DeviceContext.Provider>,
    );

    initialize();
    window.AcuantCameraUI.start.callsFake(async (callbacks) => {
      await Promise.resolve();
      callbacks.onCaptured();
      await Promise.resolve();
      callbacks.onCropped({
        glare: 70,
        sharpness: 70,
        image: {
          data: validSelfieBase64,
        },
      });
    });
    window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, validSelfieBase64);

    // Attempting to proceed without providing values will trigger error messages.
    let continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton);
    let errors = await findAllByText('simple_form.required.text');
    expect(errors).to.have.lengthOf(2);
    expect(document.activeElement).to.equal(
      getByLabelText('doc_auth.headings.document_capture_front'),
    );

    // Providing values should remove errors progressively.
    fireEvent.change(getByLabelText('doc_auth.headings.document_capture_front'), {
      target: {
        files: [validUpload],
      },
    });
    await waitFor(() => expect(getAllByText('simple_form.required.text')).to.have.lengthOf(1));
    expect(document.activeElement).to.equal(
      getByLabelText('doc_auth.headings.document_capture_front'),
    );

    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_back'));

    // Continue only once all errors have been removed.
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    continueButton = getByText('forms.buttons.continue');
    expect(isFormValid(continueButton.closest('form'))).to.be.true();
    await userEvent.click(continueButton);

    // Trigger validation by attempting to submit.
    const submitButton = getByText('forms.buttons.submit.default');

    await userEvent.click(submitButton);
    errors = await findAllByText('simple_form.required.text');
    expect(errors).to.have.lengthOf(1);
    expect(document.activeElement).to.equal(
      getByLabelText('doc_auth.headings.document_capture_selfie'),
    );

    // Provide value.
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    fireEvent.click(selfieInput);

    // Continue only once all errors have been removed.
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    expect(isFormValid(submitButton.closest('form'))).to.be.true();

    await new Promise((resolve) => {
      onSubmit.callsFake(resolve);
      userEvent.click(submitButton);
    });

    // At this point, the page should redirect, so we do not expect that the user should be prompted
    // about unsaved changes in navigating.
    const event = new window.Event('beforeunload', { cancelable: true, bubbles: false });
    window.dispatchEvent(event);
    expect(event.defaultPrevented).to.be.false();
  });

  it('renders unhandled submission failure', async () => {
    const { getByLabelText, getByText, getAllByText, findAllByText, findByText } = render(
      <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
        <DocumentCapture />
      </AcuantContextProvider>,
      {
        uploadError: new Error('Server unavailable'),
        expectedUploads: 2,
      },
    );

    const continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton);
    await findAllByText('simple_form.required.text');
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), validUpload);
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), validUpload);
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(continueButton);

    let submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    fireEvent.change(selfieInput, { target: { files: [validUpload] } });
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(submitButton);

    await findByText('doc_auth.errors.general.network_error');

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );

    // Make sure that the first element after a tab is what we expect it to be.
    await userEvent.tab();
    const firstFocusable = getByLabelText('doc_auth.headings.document_capture_front');
    expect(document.activeElement).to.equal(firstFocusable);

    const hasValueSelected = getAllByText('doc_auth.forms.change_file').length === 3;
    expect(hasValueSelected).to.be.true();

    // Verify re-submission. It will fail again, but test can at least assure that the interstitial
    // screen is shown once more.

    submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    const interstitialHeading = getByText('doc_auth.headings.interstitial');
    expect(interstitialHeading).to.be.ok();

    await findByText('doc_auth.errors.general.network_error');

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );
  });

  it('renders handled submission failure', async () => {
    const uploadError = new UploadFormEntriesError();
    uploadError.formEntryErrors = [
      { field: 'front', message: 'Image has glare' },
      { field: 'back', message: 'Please fill in this field' },
      { message: 'An unknown error occurred' },
    ].map(toFormEntryError);
    const { getByLabelText, getByText, getAllByText, findAllByText, findAllByRole } = render(
      <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
        <DocumentCapture />
      </AcuantContextProvider>,
      {
        uploadError,
        expectedUploads: 2,
      },
    );

    const continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton);
    await findAllByText('simple_form.required.text');
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), validUpload);
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), validUpload);
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(continueButton);

    let submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    fireEvent.change(selfieInput, { target: { files: [validUpload] } });
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(submitButton);

    let notices = await findAllByRole('alert');
    expect(notices[0].textContent).to.equal('Image has glare');
    expect(notices[1].textContent).to.equal('Please fill in this field');
    expect(getByText('An unknown error occurred')).to.be.ok();

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );

    // Make sure that the first focusable element after a tab is what we expect it to be.
    await userEvent.tab();
    const firstFocusable = getByLabelText('doc_auth.headings.document_capture_front');
    expect(document.activeElement).to.equal(firstFocusable);

    const hasValueSelected = !!getByLabelText('doc_auth.headings.document_capture_front');
    expect(hasValueSelected).to.be.true();

    submitButton = getByText('forms.buttons.submit.default');
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), validUpload);
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), validUpload);

    // Once fields are changed, their notices should be cleared. If all field-specific errors are
    // addressed, submit should be enabled once more.
    notices = await findAllByRole('alert');
    const errorNotices = notices.filter((notice) => notice.classList.contains('usa-alert--error'));
    expect(errorNotices).to.have.lengthOf(0);

    // Verify re-submission. It will fail again, but test can at least assure that the interstitial
    // screen is shown once more.
    await userEvent.click(submitButton);
    const interstitialHeading = getByText('doc_auth.headings.interstitial');
    expect(interstitialHeading).to.be.ok();

    await waitFor(() => expect(() => getAllByText('doc_auth.info.interstitial_eta')).to.throw());

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );
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

  it('renders async upload pending progress', async () => {
    const statusChecks = 3;
    let remainingStatusChecks = statusChecks;
    sandbox.stub(window, 'fetch').resolves({ ok: true, headers: new window.Headers() });
    const upload = sinon.stub().callsFake((payload, { endpoint }) => {
      switch (endpoint) {
        case 'about:blank#upload':
          expect(payload).to.have.keys([
            'front_image_iv',
            'front_image_url',
            'front_image_metadata',
            'back_image_iv',
            'back_image_url',
            'back_image_metadata',
            'selfie_image_iv',
            'selfie_image_url',
            'flow_path',
          ]);

          return Promise.resolve({ success: true, isPending: true });
        case 'about:blank#status':
          expect(payload).to.be.empty();

          return Promise.resolve({ success: true, isPending: Boolean(remainingStatusChecks--) });
        default:
          throw new Error();
      }
    });
    const key = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );

    const { getByLabelText, getByText, getAllByText, findAllByText } = baseRender(
      <UploadContextProvider
        endpoint="about:blank#upload"
        statusEndpoint="about:blank#status"
        statusPollInterval={0}
        backgroundUploadURLs={{
          front: 'about:blank#front',
          back: 'about:blank#back',
          selfie: 'about:blank#selfie',
        }}
        backgroundUploadEncryptKey={key}
        upload={upload}
      >
        <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
          <DocumentCapture isAsyncForm />
        </AcuantContextProvider>
      </UploadContextProvider>,
    );

    const continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton);
    await findAllByText('simple_form.required.text');
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), validUpload);
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), validUpload);
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(continueButton);

    const submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    fireEvent.change(selfieInput, { target: { files: [validUpload] } });
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(submitButton);

    return new Promise((resolve) => {
      onSubmit.callsFake(() => {
        // Error logged at initial pending retry.
        expect(console).to.have.loggedError(/^Error: Uncaught/);
        expect(console).to.have.loggedError(/React will try to recreate this component/);

        // Error logged at every scheduled check thereafter.
        for (let i = 0; i < statusChecks; i++) {
          expect(console).to.have.loggedError(/^Error: Uncaught/);
          expect(console).to.have.loggedError(/React will try to recreate this component/);
        }

        resolve();
      });

      userEvent.click(submitButton);
    });
  });

  it('calls onStepChange callback on step changes', async () => {
    const uploadError = new UploadFormEntriesError();
    uploadError.formEntryErrors = [{ field: 'front', message: '' }].map(toFormEntryError);
    const onStepChange = sinon.spy();
    const { getByLabelText, getByText, getAllByText, findAllByText } = render(
      <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
        <DocumentCapture onStepChange={onStepChange} />
      </AcuantContextProvider>,
      { uploadError },
    );

    const continueButton = getByText('forms.buttons.continue');
    await userEvent.click(continueButton);
    await findAllByText('simple_form.required.text');
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), validUpload);
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), validUpload);
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(continueButton);
    expect(onStepChange.callCount).to.equal(1);

    const submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    expect(onStepChange.callCount).to.equal(1);
    await findAllByText('simple_form.required.text');
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    await fireEvent.change(selfieInput, { target: { files: validUpload } });
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    await userEvent.click(submitButton);
    expect(onStepChange.callCount).to.equal(1);

    await waitFor(() => expect(() => getAllByText('doc_auth.info.interstitial_eta')).to.throw());

    expect(onStepChange.callCount).to.equal(1);
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

  context('desktop selfie capture', () => {
    beforeEach(() => {
      function MediaStream() {}
      MediaStream.prototype = { play() {}, getTracks() {} };
      sandbox.stub(MediaStream.prototype, 'play');
      sandbox.stub(MediaStream.prototype, 'getTracks').returns([{ stop() {} }]);
      sandbox.stub(window.HTMLMediaElement.prototype, 'play');

      defineProperty(navigator, 'mediaDevices', {
        configurable: true,
        value: {
          getUserMedia: () => Promise.resolve(new MediaStream()),
        },
      });
      defineProperty(window, 'MediaStream', {
        configurable: true,
        value: MediaStream,
      });
      defineProperty(navigator, 'permissions', {
        configurable: true,
        value: {
          query: sinon
            .stub()
            .withArgs({ name: 'camera' })
            .returns(Promise.resolve({ state: 'granted' })),
        },
      });
      sandbox.stub(window.HTMLCanvasElement.prototype, 'getContext').returns({ drawImage() {} });
      sandbox.stub(window.HTMLCanvasElement.prototype, 'toDataURL').returns('data:,');
    });

    // DOM globals are stubbed with sandbox, so run cleanup before sandbox is restored, as otherwise
    // it will attempt to reference globals which are already restored to undefined.
    afterEach(cleanup);

    it('progresses through steps to completion', async () => {
      const { getByLabelText, getByText } = render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <AcuantContextProvider sdkSrc="about:blank" cameraSrc="about:blank">
            <DocumentCapture />
          </AcuantContextProvider>
        </DeviceContext.Provider>,
      );

      await userEvent.upload(
        getByLabelText('doc_auth.headings.document_capture_front'),
        validUpload,
      );
      await userEvent.upload(
        getByLabelText('doc_auth.headings.document_capture_back'),
        validUpload,
      );

      await userEvent.click(getByText('forms.buttons.continue'));
      await userEvent.click(getByLabelText('doc_auth.buttons.take_picture'));

      await new Promise((resolve) => {
        onSubmit.callsFake(resolve);
        userEvent.click(getByText('forms.buttons.submit.default'));
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
