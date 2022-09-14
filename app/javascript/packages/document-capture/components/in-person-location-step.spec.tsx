import sinon from 'sinon';
import { useContext } from 'react';
import { render } from '@testing-library/react';
import { getAllByRole } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import AnalyticsContext, { AnalyticsContextProvider } from '../context/analytics';
import InPersonLocationStep, { LOCATIONS_URL } from './in-person-location-step';

describe('InPersonLocationStep', () => {
  const DEFAULT_PROPS = { toPreviousStep() {}, onChange() {}, value: {} };

  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox
      .stub(window, 'fetch')
      .withArgs(LOCATIONS_URL)
      .resolves({
        json: () => Promise.resolve([{ name: 'Baltimore' }]),
      } as Response);
  });

  it('logs step submission with selected location', async () => {
    const trackEvent = sinon.stub();
    function MetadataValue() {
      return <>{JSON.stringify(useContext(AnalyticsContext).submitEventMetadata)}</>;
    }
    const { findByText } = render(
      <AnalyticsContextProvider trackEvent={trackEvent}>
        <MetadataValue />
        <InPersonLocationStep {...DEFAULT_PROPS} />
      </AnalyticsContextProvider>,
    );

    const item = await findByText('Baltimore — in_person_proofing.body.location.post_office');
    const button = getAllByRole(item.closest('.location-collection-item')!, 'button')[0];

    await userEvent.click(button);

    await findByText('{"selected_location":"Baltimore"}');
  });
});
