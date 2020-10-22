import React from 'react';
import sinon from 'sinon';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import { render as baseRender, fireEvent } from '@testing-library/react';
import {
  UploadFormEntriesError,
  toFormEntryError,
} from '@18f/identity-document-capture/services/upload';
import {
  UploadContextProvider,
  AcuantProvider,
  DeviceContext,
} from '@18f/identity-document-capture';
import DocumentCapture, {
  except,
} from '@18f/identity-document-capture/components/document-capture';
import render from '../../../support/render';
import { useSandbox } from '../../../support/sinon';
import { useAcuant } from '../../../support/acuant';

describe('document-capture/components/document-capture', () => {
  const sandbox = useSandbox();
  const { initialize } = useAcuant();

  function isFormValid(form) {
    return [...form.querySelectorAll('input')].every((input) => input.checkValidity());
  }

  let originalHash;

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

  context('mobile', () => {
    it('starts with introductory step', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <DocumentCapture />
        </DeviceContext.Provider>,
      );

      expect(getByText('doc_auth.info.document_capture_intro_acknowledgment')).to.be.ok();
    });

    it('does not show document step footer', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: true }}>
          <DocumentCapture />
        </DeviceContext.Provider>,
      );

      userEvent.click(getByText('forms.buttons.continue'));

      expect(() => getByText('doc_auth.info.document_capture_upload_image')).to.throw();
    });
  });

  context('desktop', () => {
    it('shows document step footer', () => {
      const { getByText } = render(
        <DeviceContext.Provider value={{ isMobile: false }}>
          <DocumentCapture />
        </DeviceContext.Provider>,
      );

      expect(getByText('doc_auth.info.document_capture_upload_image')).to.be.ok();
    });
  });

  it('progresses through steps to completion', async () => {
    const { getByLabelText, getByText, getAllByText, findAllByText } = render(
      <AcuantProvider sdkSrc="about:blank">
        <DocumentCapture />
      </AcuantProvider>,
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
          data: 'data:image/png;base64,',
        },
      });
    });
    window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, '');

    // Continue is enabled, but attempting to proceed without providing values will trigger error
    // messages.
    let continueButton = getByText('forms.buttons.continue');
    userEvent.click(continueButton);
    let errors = await findAllByText('simple_form.required.text');
    expect(errors).to.have.lengthOf(2);
    expect(document.activeElement).to.equal(
      getByLabelText('doc_auth.headings.document_capture_front'),
    );

    // Providing values should remove errors progressively.
    fireEvent.change(getByLabelText('doc_auth.headings.document_capture_front'), {
      target: {
        files: [new window.File([''], 'upload.png', { type: 'image/png' })],
      },
    });
    await waitFor(() => expect(getAllByText('simple_form.required.text')).to.have.lengthOf(1));
    expect(document.activeElement).to.equal(
      getByLabelText('doc_auth.headings.document_capture_front'),
    );

    userEvent.click(getByLabelText('doc_auth.headings.document_capture_back'));

    // Continue only once all errors have been removed.
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    continueButton = getByText('forms.buttons.continue');
    expect(isFormValid(continueButton.closest('form'))).to.be.true();
    userEvent.click(continueButton);

    // Trigger validation by attempting to submit.
    const submitButton = getByText('forms.buttons.submit.default');
    userEvent.click(continueButton);
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

    return new Promise((resolve) => {
      const form = document.createElement('form');
      form.className = 'js-document-capture-form';
      document.body.appendChild(form);
      form.addEventListener('submit', (event) => {
        event.preventDefault();
        document.body.removeChild(form);
        resolve();
      });

      userEvent.click(submitButton);
    });
  });

  it('renders unhandled submission failure', async () => {
    const { getByLabelText, getByText, getAllByText, findAllByText, findByRole } = render(
      <AcuantProvider sdkSrc="about:blank">
        <DocumentCapture />
      </AcuantProvider>,
      {
        uploadError: new Error('Server unavailable'),
        expectedUploads: 2,
      },
    );

    initialize({ isCameraSupported: false });
    window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, '');

    const continueButton = getByText('forms.buttons.continue');
    userEvent.click(continueButton);
    await findAllByText('simple_form.required.text');
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_front'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_back'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(continueButton);

    let submitButton = getByText('forms.buttons.submit.default');
    userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    fireEvent.click(selfieInput);
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(submitButton);

    const notice = await findByRole('alert');
    expect(notice.textContent).to.equal('errors.doc_auth.acuant_network_error');

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );

    const heading = getByText('doc_auth.headings.review_issues');
    expect(document.activeElement).to.equal(heading);

    const hasValueSelected = getAllByText('doc_auth.forms.change_file').length === 3;
    expect(hasValueSelected).to.be.true();

    // Verify re-submission. It will fail again, but test can at least assure that the interstitial
    // screen is shown once more.

    submitButton = getByText('forms.buttons.submit.default');
    userEvent.click(submitButton);
    const interstitialHeading = getByText('doc_auth.headings.interstitial');
    expect(interstitialHeading).to.be.ok();

    await findByRole('alert');

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
    ].map(toFormEntryError);
    const { getByLabelText, getByText, getAllByText, findAllByText, findAllByRole } = render(
      <AcuantProvider sdkSrc="about:blank">
        <DocumentCapture />
      </AcuantProvider>,
      {
        uploadError,
      },
    );

    initialize({ isCameraSupported: false });
    window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, '');

    const continueButton = getByText('forms.buttons.continue');
    userEvent.click(continueButton);
    await findAllByText('simple_form.required.text');
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_front'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_back'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(continueButton);

    const submitButton = getByText('forms.buttons.submit.default');
    userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    fireEvent.click(selfieInput);
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(submitButton);

    const notices = await findAllByRole('alert');
    expect(notices[0].textContent).to.equal('Image has glare');
    expect(notices[1].textContent).to.equal('Please fill in this field');

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );

    const heading = getByText('doc_auth.headings.review_issues');
    expect(document.activeElement).to.equal(heading);

    const hasValueSelected = !!getByLabelText('doc_auth.headings.document_capture_front');
    expect(hasValueSelected).to.be.true();
  });

  it('renders async upload pending progress', async () => {
    const statusChecks = 3;
    let remainingStatusChecks = statusChecks;
    sandbox.stub(window, 'fetch');
    const upload = sinon.stub().callsFake((payload, { endpoint }) => {
      switch (endpoint) {
        case 'about:blank#upload':
          expect(payload).to.have.keys([
            'front_image_iv',
            'front_image_url',
            'back_image_iv',
            'back_image_url',
            'selfie_image_iv',
            'selfie_image_url',
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
        backgroundUploadURLs={{
          front: 'about:blank#front',
          back: 'about:blank#back',
          selfie: 'about:blank#back',
        }}
        backgroundUploadEncryptKey={key}
        upload={upload}
      >
        <AcuantProvider sdkSrc="about:blank">
          <DocumentCapture isAsyncForm />
        </AcuantProvider>
      </UploadContextProvider>,
    );

    initialize({ isCameraSupported: false });
    window.AcuantPassiveLiveness.startSelfieCapture.callsArgWithAsync(0, '');

    const continueButton = getByText('forms.buttons.continue');
    userEvent.click(continueButton);
    await findAllByText('simple_form.required.text');
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_front'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_back'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(continueButton);

    const submitButton = getByText('forms.buttons.submit.default');
    userEvent.click(submitButton);
    await findAllByText('simple_form.required.text');
    const selfieInput = getByLabelText('doc_auth.headings.document_capture_selfie');
    fireEvent.click(selfieInput);
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(submitButton);

    return new Promise((resolve) => {
      const form = document.createElement('form');
      form.className = 'js-document-capture-form';
      document.body.appendChild(form);
      form.addEventListener('submit', (event) => {
        event.preventDefault();
        document.body.removeChild(form);

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
});
