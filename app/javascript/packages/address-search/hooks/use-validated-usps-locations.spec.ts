import { renderHook } from '@testing-library/react-hooks';
import { rest } from 'msw';
import { setupServer } from 'msw/node';
import type { SetupServer } from 'msw/node';
import useValidatedUspsLocations from './use-validated-usps-locations';
import { LOCATIONS_URL } from '../components/in-person-location-post-office-search-step';

const USPS_RESPONSE = [
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

describe('useValidatedUspsLocations', () => {
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
    server.use(rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json(USPS_RESPONSE))));
  });

  it('returns location results', async () => {
    const { result, waitForNextUpdate } = renderHook(() =>
      useValidatedUspsLocations(LOCATIONS_URL),
    );

    const { handleLocationSearch } = result.current;
    handleLocationSearch(new Event('submit'), '200 main', 'Endeavor', 'DE', '12345');

    await waitForNextUpdate();

    expect(result.current.locationResults?.length).to.equal(USPS_RESPONSE.length);
  });
});
