import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { t } from '@18f/identity-i18n';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import type { SetupServerApi } from 'msw/node';
import { SWRConfig } from 'swr';
import { LOCATIONS_URL } from './in-person-location-step';
import { ADDRESS_SEARCH_URL } from './address-search';
import InPersonContext from '../context/in-person';
import InPersonLocationPostOfficeSearchStep from './in-person-location-post-office-search-step';

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

const MULTI_LOCATION_RESPONSE = [
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
  {
    address: '200 Main St E, Bronwood, Georgia, 39826',
    location: {
      latitude: 32.831686000000005,
      longitude: -83.363768,
    },
    street_address: '200 Main St E',
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
    server = setupServer();
    server.listen();
  });

  after(() => {
    server.close();
  });

  beforeEach(() => {
    server.resetHandlers();
  });

  context('initial API request throws an error', () => {
    beforeEach(() => {
      server.use(
        rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) => res(ctx.json(DEFAULT_RESPONSE))),
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.status(500))),
      );
    });

    it('displays a 500 error if the request to the USPS API throws an error', async () => {
      const { findByText, findByLabelText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '222 Merchandise Mart Plaza',
      );

      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const error = await findByText('idv.failure.exceptions.internal_error');
      expect(error).to.exist();
    });
  });

  context('initial API request is successful', () => {
    beforeEach(() => {
      server.use(
        rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) => res(ctx.json(DEFAULT_RESPONSE))),
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      );
    });

    it('allows search by address when enabled', async () => {
      const { findAllByText, findByText, findByLabelText, queryAllByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );

      const results = queryAllByText('in_person_proofing.body.location.location_button');

      expect(results).to.be.empty();

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '100 main',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      await findAllByText('in_person_proofing.body.location.location_button');
    });

    it('validates input and shows inline error', async () => {
      const { findByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );

      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      await findByText('in_person_proofing.body.location.inline_error');
    });

    it('displays no post office results if a successful search is followed by an unsuccessful search', async () => {
      const { findByText, findByLabelText, queryByRole } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '594 Broadway New York',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        'asdfkf',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const results = queryByRole('status', {
        name: 'in_person_proofing.body.location.location_button',
      });
      expect(results).not.to.exist();
    });

    it('clicking search again after first results do not clear results', async () => {
      const { findAllByText, findByText, findByLabelText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '800 main',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      await findAllByText('in_person_proofing.body.location.location_button');
    });

    it('displays correct pluralization for a single location result', async () => {
      const { findByLabelText, findByText, getByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '800 main',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const searchResultAlert = findByText(
        t('in_person_proofing.body.location.po_search.results_description', {
          address: '222 Merchandise Mart Plaza',
          count: DEFAULT_RESPONSE.length,
        }),
      );
      expect(searchResultAlert).to.exist();
    });

    before(() => {
      server.use(
        rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) => res(ctx.json(MULTI_LOCATION_RESPONSE))),
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      );
    });

    it('displays correct pluralization for multiple location results', async () => {
      const { findByLabelText, findByText, getByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '800 main',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      const searchResultAlert = findByText(
        t('in_person_proofing.body.location.po_search.results_description', {
          address: '222 Merchandise Mart Plaza',
          count: MULTI_LOCATION_RESPONSE.length,
        }),
      );
      expect(searchResultAlert).to.exist();
    });
  });

  context('subsequent network failures clear results', () => {
    beforeEach(() => {
      server.use(
        rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) => res(ctx.json(DEFAULT_RESPONSE))),
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      );
    });

    it('subsequent failure clears previous results', async () => {
      const { findAllByText, findByText, findByLabelText, queryAllByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
            <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
          </InPersonContext.Provider>
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '400 main',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      const result = await findAllByText('in_person_proofing.body.location.location_button');

      expect(result).to.exist();

      server.use(
        rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) =>
          res(
            ctx.json([
              {
                address: '500 Main St E, Bronwood, Georgia, 39826',
                location: {
                  latitude: 31.831686000000005,
                  longitude: -84.363768,
                },
                street_address: '500 Main St E',
                city: 'Bronwood',
                state: 'GA',
                zip_code: '39826',
              },
            ]),
          ),
        ),
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.status(500))),
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '500 main',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );
      const moreResults = await queryAllByText('in_person_proofing.body.location.location_button');

      expect(moreResults).to.be.empty();
    });
  });
});
