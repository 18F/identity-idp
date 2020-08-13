import React from 'react';
import { render } from '@testing-library/react';
import SubmissionPending from '@18f/identity-document-capture/components/submission-pending';

describe('document-capture/components/submission-pending', () => {
  it('renders interstitial content', () => {
    const { getByText } = render(<SubmissionPending />);

    const heading = getByText('doc_auth.headings.interstitial');

    expect(heading).to.be.ok();
  });
});
