import { render } from '@testing-library/react';
import SubmissionInterstitial from '@18f/identity-document-capture/components/submission-interstitial';

describe('document-capture/components/submission-interstitial', () => {
  it('renders interstitial content', () => {
    const { getByText } = render(<SubmissionInterstitial />);

    const heading = getByText('doc_auth.headings.interstitial');

    expect(heading).to.be.ok();
  });

  it('autofocuses heading on opt-in', () => {
    const { getByText } = render(<SubmissionInterstitial autoFocus />);

    const heading = getByText('doc_auth.headings.interstitial');

    expect(document.activeElement).to.equal(heading);
  });
});
