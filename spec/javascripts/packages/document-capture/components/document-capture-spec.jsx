import React from 'react';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import DocumentCapture from '@18f/identity-document-capture/components/document-capture';
import render from '../../../support/render';

describe('document-capture/components/document-capture', () => {
  let originalHash;

  beforeEach(() => {
    originalHash = window.location.hash;
  });

  afterEach(() => {
    window.location.hash = originalHash;
  });

  it('renders the form steps', () => {
    const { getByText } = render(<DocumentCapture />);

    const step = getByText('doc_auth.headings.document_capture_front');

    expect(step).to.be.ok();
  });

  it('progresses through steps to completion', async () => {
    const { getByLabelText, getByText, findByText } = render(<DocumentCapture />);

    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_front'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_back'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    const continueButton = getByText('forms.buttons.continue');
    await waitFor(() => expect(continueButton.disabled).to.be.false());
    userEvent.click(continueButton);
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_selfie'),
      new window.File([''], 'selfie.png', { type: 'image/png' }),
    );
    const submitButton = getByText('forms.buttons.submit.default');
    await waitFor(() => expect(submitButton.disabled).to.be.false());
    userEvent.click(submitButton);

    const confirmation = await findByText(
      'Finished sending: {"front_image":"data:image/png;base64,","back_image":"data:image/png;base64,","selfie":"data:image/png;base64,"}',
    );

    expect(confirmation).to.be.ok();
  });

  it('handles submission failure', async () => {
    const { getByLabelText, getByText, findByRole } = render(<DocumentCapture />, {
      isUploadFailure: true,
      expectedUploads: 2,
    });

    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_front'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_back'),
      new window.File([''], 'upload.png', { type: 'image/png' }),
    );
    const continueButton = getByText('forms.buttons.continue');
    await waitFor(() => expect(continueButton.disabled).to.be.false());
    userEvent.click(continueButton);
    userEvent.upload(
      getByLabelText('doc_auth.headings.document_capture_selfie'),
      new window.File([''], 'selfie.png', { type: 'image/png' }),
    );
    let submitButton = getByText('forms.buttons.submit.default');
    await waitFor(() => expect(submitButton.disabled).to.be.false());
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
});
