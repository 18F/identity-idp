import { render } from '@testing-library/react';
import { useSandbox } from '@18f/identity-test-helpers';
import userEvent from '@testing-library/user-event';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import type { SetupServer } from 'msw/node';
import { SWRConfig } from 'swr';
import AddressSearch from '.';

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

const LOCATIONS_URL = 'https://login.gov/api/locations';
const ADDRESSES_URL = 'https://login.gov/api/addresses';

describe('AddressSearch', () => {
  const sandbox = useSandbox();
  context('when an address is found', () => {
    let server: SetupServer;
    before(() => {
      server = setupServer(
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
        rest.post(ADDRESSES_URL, (_req, res, ctx) => res(ctx.json(DEFAULT_RESPONSE))),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('fires the callback with correct input', async () => {
      const handleAddressFound = sandbox.stub();
      const handleLocationsFound = sandbox.stub();
      const { findByText, findByLabelText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <AddressSearch
            onFoundAddress={handleAddressFound}
            onFoundLocations={handleLocationsFound}
            locationsURL={LOCATIONS_URL}
            addressSearchURL={ADDRESSES_URL}
          />
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
        '200 main',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      await expect(handleAddressFound).to.eventually.be.called();
      await expect(handleLocationsFound).to.eventually.be.called();
    });
  });
});
