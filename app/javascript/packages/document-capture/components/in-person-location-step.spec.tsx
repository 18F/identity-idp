import sinon from 'sinon';
import { useContext } from 'react';
import { render } from '@testing-library/react';
import { getAllByRole } from '@testing-library/dom';
import userEvent from '@testing-library/user-event';
import { fetch } from 'whatwg-fetch';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import type { SetupServerApi } from 'msw/node';
import AnalyticsContext, { AnalyticsContextProvider } from '../context/analytics';
import InPersonLocationStep, { LOCATIONS_URL } from './in-person-location-step';
import InPersonLocationPostOfficeSearchStep from './in-person-location-post-office-search-step';
import { ADDRESS_SEARCH_URL } from './address-search';
import InPersonContext from '../context/in-person';

const DEFAULT_RESPONSE = [
  {
    address: '100 Main St E, Bronwood, Georgia, 39826',
    location: {
      latitude: 31.831686000000005,
      longitude: -84.363768,
    },
    street_address: '100 Main St E',
    city: 'Bronwood',
    state: 'GA',
    zip_code: '39826',
  },
];

const DEFAULT_PROPS = {
  toPreviousStep() {},
  onChange() {},
  value: {},
  registerField() {},
};

describe('InPersonLocationStep', () => {
  let server: SetupServerApi;
  before(() => {
    global.window.fetch = fetch;
    server = setupServer(
      rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) => res(ctx.json(DEFAULT_RESPONSE))),
      rest.put(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ success: true }]))),
    );
    server.listen();
  });

  after(() => {
    server.close();
    global.window.fetch = () => Promise.reject(new Error('Fetch must be stubbed'));
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

  it('allows search by address when enabled', async () => {
    const { findByText, findByLabelText } = render(
      <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
      </InPersonContext.Provider>,
    );

    await userEvent.type(
      await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
      '100 main',
    );
    await userEvent.click(
      await findByText('in_person_proofing.body.location.po_search.search_button'),
    );
    await findByText('in_person_proofing.body.location.po_search.results_description');
  });

  it('validates input and shows inline error', async () => {
    const { findByText } = render(
      <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
      </InPersonContext.Provider>,
    );

    await userEvent.click(
      await findByText('in_person_proofing.body.location.po_search.search_button'),
    );

    await findByText('in_person_proofing.body.location.inline_error');
  });
});
