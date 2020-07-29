import React from 'react';
import { render } from '@testing-library/react';
import SubmissionPending from '../../../../../app/javascript/app/document-capture/components/submission-pending';

describe('document-capture/components/submission-pending', () => {
  it('renders interstitial content', () => {
    const { getByText } = render(<SubmissionPending />);

    const heading = getByText('We are processing your images…');

    expect(heading).to.be.ok();
  });
});
