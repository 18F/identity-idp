import sinon from 'sinon';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import { AnalyticsContextProvider } from '../context/analytics';
import InPersonCallToAction from './in-person-call-to-action';

describe('InPersonCallToAction', () => {
  it('renders a section with a heading', () => {
    const { getByRole } = render(<InPersonCallToAction />);

    const heading = getByRole('heading');
    
    expect(heading.textContent).to.equals('in_person_proofing.headings.cta')
  });

  it('logs an event when clicking the call to action button', async () => {
    const trackEvent = sinon.stub();
    const { getByRole } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <InPersonCallToAction />
      </AnalyticsContextProvider>,
    );

    const link = getByRole('link', { name: 'in_person_proofing.body.cta.button' });
    await userEvent.click(link);

    expect(trackEvent).to.have.been.calledWith(
      'IdV: verify in person troubleshooting option clicked',
    );
  });
});
