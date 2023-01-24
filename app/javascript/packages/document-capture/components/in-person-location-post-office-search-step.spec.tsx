import { render } from '@testing-library/react';
import { useSandbox } from '@18f/identity-test-helpers';
import userEvent from '@testing-library/user-event';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import type { SetupServerApi } from 'msw/node';
import { LOCATIONS_URL } from './in-person-location-step';
import AddressSearch, { ADDRESS_SEARCH_URL } from './address-search';
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

const DEFAULT_PROPS = {
  toPreviousStep() {},
  onChange() {},
  value: {},
  registerField() {},
};

describe('InPersonLocationStep', () => {
  context('initial API request throws an error', () => {
    let server: SetupServerApi;
    beforeEach(() => {
      server = setupServer(
        rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) => res(ctx.json(DEFAULT_RESPONSE))),
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.status(500))),
      );
      server.listen();
    });

    afterEach(() => {
      server.close();
    });

    it('displays a 500 error if the request to the USPS API throws an error', async () => {
      const sandbox = useSandbox();
      const registerField = sandbox.stub();
      const handleAddressFound = sandbox.stub();
      const handleLocationsFound = sandbox.stub();
      const handleError = (_: Error | null) => {};
      const ADDRESS_SEARCH_PROPS = {
        registerField,
        onFoundAddress: handleAddressFound,
        onFoundLocations: handleLocationsFound,
        onError: handleError,
      };

      const { findByText, findByLabelText } = render(
        <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
          <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS}>
            <AddressSearch {...ADDRESS_SEARCH_PROPS} />
          </InPersonLocationPostOfficeSearchStep>
        </InPersonContext.Provider>,
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
    let server: SetupServerApi;
    beforeEach(() => {
      server = setupServer(
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
        rest.post(ADDRESS_SEARCH_URL, (_req, res, ctx) => res(ctx.json(DEFAULT_RESPONSE))),
      );
      server.listen();
    });

    afterEach(() => {
      server.close();
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

    it('displays no post office results if a successful search is followed by an unsuccessful search', async () => {
      const { findByText, findByLabelText, queryByRole } = render(
        <InPersonContext.Provider value={{ arcgisSearchEnabled: true }}>
          <InPersonLocationPostOfficeSearchStep {...DEFAULT_PROPS} />
        </InPersonContext.Provider>,
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
        name: 'in_person_proofing.body.location.po_search.results_description',
      });
      expect(results).not.to.exist();
    });
  });
});
