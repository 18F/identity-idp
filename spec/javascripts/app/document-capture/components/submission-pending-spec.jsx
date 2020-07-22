import React from 'react';
import { render } from '@testing-library/react';
import sinon from 'sinon';
import SubmissionPending from '../../../../../app/javascript/app/document-capture/components/submission-pending';
import { useFakeTimers } from '../../../support/timers';

describe('document-capture/components/submission-pending', () => {
  const getClock = useFakeTimers();

  it('renders interstitial content', () => {
    const { getByText } = render(<SubmissionPending onComplete={() => {}} />);

    const heading = getByText('We are processing your images…');

    expect(heading).to.be.ok();
  });

  it('triggers completion callback', () => {
    const spy = sinon.spy();
    render(<SubmissionPending onComplete={spy} />);

    getClock().tick(3000);

    expect(spy.calledOnce).to.be.true();
  });
});
