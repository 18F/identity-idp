import { render } from '@testing-library/react';
import sinon from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import { SWRConfig } from 'swr';
import AddressSearch from './address-search';

describe('AddressSearch', () => {
  const sandbox = useSandbox();
  const locationsURL = 'https://localhost:3000/locations/endpoint';

  context('Page Heading and PO Search About Message', () => {
    it('both render when handleLocationSelect is not null', async () => {
      const handleLocationsFound = sandbox.stub();
      const onSelect = sinon.stub();
      const { queryByText, queryByRole } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <AddressSearch
            addressSearchURL={'test'}
            disabled={false}
            handleLocationSelect={onSelect}
            locationsURL={locationsURL}
            onFoundLocations={handleLocationsFound}
            registerField={() => undefined}
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
      const onSelect = sinon.stub();
      const { queryByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <AddressSearch
            addressSearchURL={'test'}
            disabled={false}
            handleLocationSelect={onSelect}
            locationsURL={locationsURL}
            onFoundLocations={handleLocationsFound}
            registerField={() => undefined}
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
});
