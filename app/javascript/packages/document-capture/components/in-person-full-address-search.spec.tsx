import { render } from '@testing-library/react';
import { useSandbox } from '@18f/identity-test-helpers';
import userEvent from '@testing-library/user-event';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import type { SetupServer } from 'msw/node';
import { SWRConfig } from 'swr';
import FullAddressSearch from './in-person-full-address-search';
import { LOCATIONS_URL } from './in-person-location-post-office-search-step';

describe('FullAddressSearch', () => {
  const sandbox = useSandbox();

  context('validates form', () => {
    it('displays an error for all required fields when input is empty', async () => {
      const handleLocationsFound = sandbox.stub();
      const { findByText, findAllByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch onFoundLocations={handleLocationsFound} locationsURL={LOCATIONS_URL} />
        </SWRConfig>,
      );

      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const errors = await findAllByText('simple_form.required.text');
      expect(errors).to.have.lengthOf(4);
    });

    it('displays an error for an invalid ZIP code length (length = 1)', async () => {
      const handleLocationsFound = sandbox.stub();
      const { findByText, findByLabelText, findAllByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch onFoundLocations={handleLocationsFound} locationsURL={LOCATIONS_URL} />
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_label'),
        '200 main',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.city_label'),
        'Endeavor',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.state_label'),
        'DE',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.zipcode_label'),
        '1',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const errors = await findAllByText('idv.errors.pattern_mismatch.zipcode_five');
      expect(errors).to.have.lengthOf(1);
    });

    it('does not display an error for a valid ZIP code length (length = 5)', async () => {
      const handleLocationsFound = sandbox.stub();
      const { findByText, findByLabelText, queryByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch onFoundLocations={handleLocationsFound} locationsURL={LOCATIONS_URL} />
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_label'),
        '200 main',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.city_label'),
        'Endeavor',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.state_label'),
        'DE',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.zipcode_label'),
        '17201',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      expect(queryByText('idv.errors.pattern_mismatch.zipcode')).to.be.null;
    });
  });

  context('when an address is found', () => {
    let server: SetupServer;
    before(() => {
      server = setupServer(
        rest.post(LOCATIONS_URL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('fires the callback with correct input', async () => {
      const handleLocationsFound = sandbox.stub();
      const { findByText, findByLabelText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch onFoundLocations={handleLocationsFound} locationsURL={LOCATIONS_URL} />
        </SWRConfig>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_label'),
        '200 main',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.city_label'),
        'Endeavor',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.state_label'),
        'DE',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.zipcode_label'),
        '17201',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      await expect(handleLocationsFound).to.eventually.be.called();
    });
  });
});
