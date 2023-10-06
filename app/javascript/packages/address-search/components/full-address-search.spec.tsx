import { render } from '@testing-library/react';
import sinon from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import userEvent from '@testing-library/user-event';
import { setupServer } from 'msw/node';
import { rest } from 'msw';
import type { SetupServer } from 'msw/node';
import { SWRConfig } from 'swr';
import FullAddressSearch from './full-address-search';

describe('FullAddressSearch', () => {
  const sandbox = useSandbox();
  const locationsURL = 'https://localhost:3000/locations/endpoint';
  const usStatesTerritories = [['Delware', 'DE']];

  context('Page Heading and PO Search About Message', () => {
    it('both render when handleLocationSelect is not null', async () => {
      const handleLocationsFound = sandbox.stub();
      const onSelect = sinon.stub();
      const { queryByText, queryByRole } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={onSelect}
            disabled={false}
          />
        </SWRConfig>,
      );

      const heading = await queryByText('in_person_proofing.headings.po_search.location');
      const aboutMessage = await queryByText(
        'in_person_proofing.body.location.po_search.po_search_about',
      );

      expect(heading).to.exist();
      expect(aboutMessage).to.exist();
      expect(
        queryByRole('heading', { name: 'in_person_proofing.headings.po_search.location' }),
      ).to.exist();
    });

    it('both do not render when handleLocationSelect is null', async () => {
      const handleLocationsFound = sandbox.stub();
      const { queryByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={null}
            disabled={false}
          />
        </SWRConfig>,
      );

      const heading = await queryByText('in_person_proofing.headings.po_search.location');
      const aboutMessage = await queryByText(
        'in_person_proofing.body.location.po_search.po_search_about',
      );
      expect(heading).to.be.empty;
      expect(aboutMessage).to.be.empty;
    });
  });

  context('Address Search Label Text', () => {
    it('does not render when handleLocationSelect is not null', async () => {
      const handleLocationsFound = sandbox.stub();
      const onSelect = sinon.stub();
      const { queryByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={onSelect}
            disabled={false}
          />
        </SWRConfig>,
      );

      const searchLabel = await queryByText('in_person_proofing.headings.po_search.address_search_label');
      expect(searchLabel).to.be.empty;
    });

    it('renders when handleLocationSelect is null', async () => {
      const handleLocationsFound = sandbox.stub();
      const { queryByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={null}
            disabled={false}
          />
        </SWRConfig>,
      );

      const searchLabel = await queryByText('in_person_proofing.body.location.po_search.address_search_label');
      expect(searchLabel).to.exist();
    });
  });

  context('validates form', () => {
    it('displays an error for all required fields when input is empty', async () => {
      const handleLocationsFound = sandbox.stub();
      const { findByText, findAllByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={undefined}
            disabled={false}
          />
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
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={undefined}
            disabled={false}
          />
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
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={undefined}
            disabled={false}
          />
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
        rest.post(locationsURL, (_req, res, ctx) => res(ctx.json([{ name: 'Baltimore' }]))),
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
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={undefined}
            disabled={false}
          />
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
