import React from 'react';
import userEvent from '@testing-library/user-event';
import render from '../../../support/render';
import DocumentCapture from '../../../../../app/javascript/app/document-capture/components/document-capture';

describe('document-capture/components/document-capture', () => {
  it('renders the form steps', () => {
    const { getByText } = render(<DocumentCapture />);

    const step = getByText('Front');

    expect(step).to.be.ok();
  });

  it('progresses through steps to completion', async () => {
    const { getByText, findByText, getByRole } = render(<DocumentCapture />);

    userEvent.type(getByRole('textbox'), 'abc');
    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.continue'));
    userEvent.click(getByText('forms.buttons.submit.default'));

    const confirmation = await findByText('Finished sending: {"front":"abc"}');

    expect(confirmation).to.be.ok();
  });
});
