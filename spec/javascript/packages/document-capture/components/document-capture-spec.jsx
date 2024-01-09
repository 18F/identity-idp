import userEvent from '@testing-library/user-event';
import { fireEvent } from '@testing-library/react';
import { waitFor } from '@testing-library/dom';
import httpUpload, {
  UploadFormEntriesError,
  toFormEntryError,
} from '@18f/identity-document-capture/services/upload';
import {
  ServiceProviderContextProvider,
  UploadContextProvider,
  AcuantContextProvider,
  DeviceContext,
  InPersonContext,
} from '@18f/identity-document-capture';
import DocumentCapture from '@18f/identity-document-capture/components/document-capture';
import { FlowContext } from '@18f/identity-verify-flow';
import { expect } from 'chai';
import { useSandbox } from '@18f/identity-test-helpers';
import { AcuantDocumentType } from '@18f/identity-document-capture/components/acuant-camera';
import { render, useAcuant, useDocumentCaptureForm } from '../../../support/document-capture';
import { getFixtureFile } from '../../../support/file';

describe('document-capture/components/document-capture', () => {
  const onSubmit = useDocumentCaptureForm();
  const sandbox = useSandbox();
  const { initialize } = useAcuant();

  function isFormValid(form) {
    return [...form.querySelectorAll('input')].every((input) => input.checkValidity());
  }

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

  it('does not render the selfie capture by default', () => {
    const { queryByText } = render(<DocumentCapture />);

    const selfie = queryByText('doc_auth.headings.document_capture_selfie');

    expect(selfie).not.to.exist();
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
    window.AcuantCameraUI.start.callsFake(({ _onCaptured, _onCropped, onError }) =>
      onError(new Error()),
    );

    await userEvent.click(getByLabelText('doc_auth.headings.document_capture_front'));

    await findByText('doc_auth.errors.camera.blocked_detail');
  });

  it('progresses through steps to completion', async () => {
    const { getByLabelText, getByText, getAllByText, findAllByText, queryByText } = render(
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
          data: validUpload,
        },
        cardType: AcuantDocumentType.ID,
      });
    });

    // Attempting to proceed without providing values will trigger error messages.
    let submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    const errors = await findAllByText('simple_form.required.text');
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

    // Ensure the selfie field does not appear
    const selfie = queryByText('doc_auth.headings.document_capture_selfie');
    expect(selfie).not.to.exist();

    // Continue only once all errors have been removed.
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    submitButton = getByText('forms.buttons.submit.default');
    expect(isFormValid(submitButton.closest('form'))).to.be.true();

    await new Promise((resolve) => {
      onSubmit.callsFake(resolve);
      // eslint-disable-next-line no-restricted-syntax
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

    let submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), validUpload);
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), validUpload);
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

    const hasValueSelected = getAllByText('doc_auth.forms.change_file').length === 2;
    expect(hasValueSelected).to.be.true();

    // Verify re-submission. It will fail again, but test can at least assure that the interstitial
    // screen is shown once more.

    submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);

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

    let submitButton = getByText('forms.buttons.submit.default');
    await userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_front'), validUpload);
    await userEvent.upload(getByLabelText('doc_auth.headings.document_capture_back'), validUpload);
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
    // Since the error wasn't related to an unsupported document type, user should see a help center link.
    await userEvent.tab();
    const firstFocusable = getByText('doc_auth.info.review_examples_of_photos');
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

    const response = new Response(JSON.stringify({ redirect: '#teapot' }), { status: 418 });
    sandbox.stub(response, 'url').get(() => endpoint);
    sandbox.stub(global, 'fetch').withArgs(endpoint).resolves(response);

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
        const { getByLabelText, getByText, queryByText, findByText } = render(
          <UploadContextProvider upload={httpUpload} endpoint={endpoint}>
            <ServiceProviderContextProvider value={{ isLivenessRequired: false }}>
              <FlowContext.Provider
                value={{
                  cancelURL: '/cancel',
                  currentStep: 'document_capture',
                }}
              >
                <InPersonContext.Provider
                  value={{
                    inPersonURL: '/in_person',
                  }}
                >
                  <DocumentCapture />
                </InPersonContext.Provider>
              </FlowContext.Provider>
            </ServiceProviderContextProvider>
          </UploadContextProvider>,
        );

        const response = new Response(
          JSON.stringify({ success: false, remaining_attempts: 1, errors: [{}] }),
          { status: 400 },
        );
        sandbox.stub(response, 'url').get(() => endpoint);
        sandbox.stub(global, 'fetch').withArgs(endpoint).resolves(response);

        expect(queryByText('idv.troubleshooting.options.verify_in_person')).not.to.exist();
        await userEvent.click(getByText('forms.buttons.submit.default'));
        expect(queryByText('idv.troubleshooting.options.verify_in_person')).not.to.exist();

        const frontImage = getByLabelText('doc_auth.headings.document_capture_front');
        const backImage = getByLabelText('doc_auth.headings.document_capture_back');
        await userEvent.upload(frontImage, validUpload);
        await userEvent.upload(backImage, validUpload);
        await waitFor(() => frontImage.src && backImage.src);

        await userEvent.click(getByText('forms.buttons.submit.default'));

        const verifyInPersonButton = await findByText('in_person_proofing.body.cta.button');
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
