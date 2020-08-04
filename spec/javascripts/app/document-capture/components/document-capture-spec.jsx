import React from 'react';
import userEvent from '@testing-library/user-event';
import { waitFor } from '@testing-library/dom';
import render from '../../../support/render';
import DocumentCapture from '../../../../../app/javascript/app/document-capture/components/document-capture';

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
});
