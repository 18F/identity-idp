import sinon from 'sinon';
import { computeAccessibleName } from 'dom-accessibility-api';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { AnalyticsContextProvider } from '../context/analytics';
import InPersonCallToAction from './in-person-call-to-action';

describe('InPersonCallToAction', () => {
  it('renders a section with an accessible heading', () => {
    const { getByRole } = render(<InPersonCallToAction />);
    const heading = getByRole('heading');
    expect(computeAccessibleName(heading)).to.equals('in_person_proofing.headings.cta');
  });

  it('logs an event when clicking the call to action button', async () => {
    const trackEvent = sinon.stub();
    const { getByRole } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <InPersonCallToAction />
      </AnalyticsContextProvider>,
    );

    const button = getByRole('button', { name: 'in_person_proofing.body.cta.button' });
    await userEvent.click(button);

    expect(trackEvent).to.have.been.calledWith(
      'IdV: verify in person troubleshooting option clicked',
    );
  });
});
