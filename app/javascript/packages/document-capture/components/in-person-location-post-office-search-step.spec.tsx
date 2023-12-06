import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { i18n } from '@18f/identity-i18n';
import { usePropertyValue } from '@18f/identity-test-helpers';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import type { SetupServer } from 'msw/node';
import { SWRConfig } from 'swr';
import { ComponentType } from 'react';
import { InPersonContext } from '../context';
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

describe('InPersonLocationPostOfficeSearchStep', () => {
  const usStatesTerritories: [string, string][] = [['Delware', 'DE']];
  const locationsURL = 'https://localhost:3000/locations/endpoint';
  const addressSearchURL = 'https://localhost:3000/addresses/endpoint';
  const wrapper: ComponentType = ({ children }) => (
    <InPersonContext.Provider
      value={{
        locationsURL,
        addressSearchURL,
        inPersonOutageMessageEnabled: false,
        inPersonOutageExpectedUpdateDate: 'January 1, 2024',
        inPersonFullAddressEntryEnabled: true,
        optedInToInPersonProofing: false,
        usStatesTerritories,
      }}
    >
      <SWRConfig value={{ provider: () => new Map() }}>{children}</SWRConfig>
    </InPersonContext.Provider>
  );

  let server: SetupServer;

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

  context('initial ArcGIS API request throws an error', () => {
    beforeEach(() => {
      server.use(
        rest.post(addressSearchURL, (_req, res, ctx) => res(ctx.json([]), ctx.status(422))),
      );
    });

    it('displays a try again error message', async () => {
      const { findByText, findByLabelText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '222 Merchandise Mart Plaza',
      );

      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const error = await findByText('idv.failure.exceptions.post_office_search_error');
      expect(error).to.exist();
    });
  });
  context('initial USPS API request throws an error', () => {
    beforeEach(() => {
      server.use(
        rest.post(addressSearchURL, (_req, res, ctx) =>
          res(ctx.json(DEFAULT_RESPONSE), ctx.status(200)),
        ),
        rest.post(locationsURL, (_req, res, ctx) => res(ctx.status(500))),
      );
    });

    it('displays a try again error message', async () => {
      const { findByText, findByLabelText } = render(
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
        { wrapper },
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '222 Merchandise Mart Plaza',
      );

      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const error = await findByText('idv.failure.exceptions.post_office_search_error');
      expect(error).to.exist();
    });
  });

  context('initial API request is successful', () => {
    beforeEach(() => {
      server.use(
        rest.post(addressSearchURL, (_req, res, ctx) =>
          res(ctx.json(DEFAULT_RESPONSE), ctx.status(200)),
        ),
        rest.post(locationsURL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      );
    });

    it('allows search by address when enabled', async () => {
      const { findAllByText, findByText, findByLabelText, queryAllByText } = render(
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
        { wrapper },
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
      const { findByText } = render(<InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />, {
        wrapper,
      });

      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      await findByText('in_person_proofing.body.location.inline_error');
    });

    it('displays no post office results if a successful search is followed by an unsuccessful search', async () => {
      const { findByText, findByLabelText, queryByRole } = render(
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
        { wrapper },
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
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
        { wrapper },
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

    context('pluralized and singularized translations are set', () => {
      usePropertyValue(i18n, 'strings', {
        'in_person_proofing.body.location.po_search.results_description': {
          one: 'There is one participating Post Office within 50 miles of %{address}.',
          other: 'There are %{count} participating Post Offices within 50 miles of %{address}.',
        },
      });

      it('displays correct pluralization for a single location result', async () => {
        const { findByLabelText, findByText } = render(
          <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
          { wrapper },
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

        const searchResultAlert = await findByText(
          `There is one participating Post Office within 50 miles of ${MULTI_LOCATION_RESPONSE[0].address}.`,
        );
        expect(searchResultAlert).to.exist();
      });

      it('displays correct pluralization for multiple location results', async () => {
        server.resetHandlers();
        server.use(
          rest.post(addressSearchURL, (_req, res, ctx) =>
            res(ctx.json(DEFAULT_RESPONSE), ctx.status(200)),
          ),
          rest.post(locationsURL, (_req, res, ctx) => res(ctx.json(MULTI_LOCATION_RESPONSE))),
        );
        const { findByLabelText, findByText } = render(
          <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
          { wrapper },
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
        const searchResultAlert = await findByText(
          `There are ${MULTI_LOCATION_RESPONSE.length} participating Post Offices within 50 miles of ${MULTI_LOCATION_RESPONSE[0].address}.`,
        );
        expect(searchResultAlert).to.exist();
      });
    });
  });

  context('subsequent network failures clear results', () => {
    beforeEach(() => {
      server.use(
        rest.post(addressSearchURL, (_req, res, ctx) =>
          res(ctx.json(DEFAULT_RESPONSE), ctx.status(200)),
        ),
        rest.post(locationsURL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      );
    });

    it('subsequent failure clears previous results', async () => {
      const { findAllByText, findByText, findByLabelText, queryAllByText } = render(
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
        { wrapper },
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
        rest.post(addressSearchURL, (_req, res, ctx) =>
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
            ctx.status(200),
          ),
        ),
        rest.post(locationsURL, (_req, res, ctx) => res(ctx.status(500))),
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

  context('user deletes text from searchbox after location results load', () => {
    beforeEach(() => {
      server.use(
        rest.post(addressSearchURL, (_req, res, ctx) =>
          res(ctx.json(DEFAULT_RESPONSE), ctx.status(200)),
        ),
        rest.post(locationsURL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      );
    });

    it('allows user to select a location', async () => {
      const { findAllByText, findByLabelText, findByText, queryByText } = render(
        <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />,
        { wrapper },
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        'Evergreen Terrace Springfield',
      );

      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      await userEvent.clear(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
      );

      await userEvent.click(findAllByText('in_person_proofing.body.location.location_button')[0]);

      expect(await queryByText('in_person_proofing.body.location.inline_error')).to.be.null();
    });
  });
});
