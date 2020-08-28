import React from 'react';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import { fireEvent } from '@testing-library/react';
import {
  UploadFormEntriesError,
  toFormEntryError,
} from '@18f/identity-document-capture/services/upload';
import { AcuantProvider } from '@18f/identity-document-capture';
import DocumentCapture, {
  getInitialStep,
} from '@18f/identity-document-capture/components/document-capture';
import render from '../../../support/render';
import { useAcuant } from '../../../support/acuant';

describe('document-capture/components/document-capture', () => {
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

  describe('getInitialStep', () => {
    const steps = [
      { name: 'first' },
      { name: 'second', fields: ['a', 'b'] },
      { name: 'third', fields: ['c'] },
    ];

    it('undefined if there are no errors', () => {
      const initialStep = getInitialStep(steps, []);

      expect(initialStep).to.be.undefined();
    });

    it('returns undefined if step for error field does not exist', () => {
      const initialStep = getInitialStep(steps, [
        toFormEntryError({ field: 'network', message: 'Unknown' }),
      ]);

      expect(initialStep).to.be.undefined();
    });

    it('returns first of steps where error exists', () => {
      const initialStep = getInitialStep(steps, [
        toFormEntryError({ field: 'b', message: 'Field is missing' }),
      ]);

      expect(initialStep).to.be.equal('second');
    });
  });

  it('renders the form steps', () => {
    const { getByText } = render(<DocumentCapture />);

    const step = getByText('doc_auth.headings.document_capture_front');

    expect(step).to.be.ok();
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
    const didClick = fireEvent.click(selfieInput);
    expect(didClick).to.be.true();
    fireEvent.change(selfieInput, {
      target: {
        files: [new window.File([''], 'upload.png', { type: 'image/png' })],
      },
    });

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
      <DocumentCapture />,
      {
        uploadError: new Error('Server unavailable'),
        expectedUploads: 2,
      },
    );

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
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_selfie'),
      new window.File([''], 'selfie.png', { type: 'image/png' }),
    );
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(submitButton);

    const notice = await findByRole('alert');
    expect(notice.textContent).to.equal('errors.doc_auth.acuant_network_error');

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );

    const heading = getByText('doc_auth.headings.selfie');
    expect(document.activeElement).to.equal(heading);

    const hasValueSelected = !!getByText('doc_auth.forms.change_file');
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
    uploadError.rawErrors = [
      { field: 'front', message: 'Image has glare' },
      { field: 'back', message: 'Please fill in this field' },
    ].map(toFormEntryError);
    const { getByLabelText, getByText, getAllByText, findAllByText, findAllByRole } = render(
      <DocumentCapture />,
      {
        uploadError,
      },
    );

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
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_selfie'),
      new window.File([''], 'selfie.png', { type: 'image/png' }),
    );
    await waitFor(() => expect(() => getAllByText('simple_form.required.text')).to.throw());
    userEvent.click(submitButton);

    const notices = await findAllByRole('alert');
    expect(notices[0].textContent).to.equal('Image has glare');
    expect(notices[1].textContent).to.equal('Please fill in this field');

    expect(console).to.have.loggedError(/^Error: Uncaught/);
    expect(console).to.have.loggedError(
      /React will try to recreate this component tree from scratch using the error boundary you provided/,
    );

    const front = getByLabelText('doc_auth.headings.document_capture_front');
    expect(document.activeElement).to.equal(front);
  });
});
