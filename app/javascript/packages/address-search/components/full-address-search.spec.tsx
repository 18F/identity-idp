import { render } from '@testing-library/react';
import sinon from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import userEvent from '@testing-library/user-event';
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import type { SetupServer } from 'msw/node';
import { SWRConfig } from 'swr';
import { I18n } from '@18f/identity-i18n';
import { I18nContext } from '@18f/identity-react-i18n';
import FullAddressSearch from './full-address-search';

describe('FullAddressSearch', () => {
  const sandbox = useSandbox();
  const locationsURL = 'https://localhost:3000/locations/endpoint';
  const usStatesTerritories = [['Delware', 'DE']];

  context('Page Heading and PO Search About Message', () => {
    it('both render when handleLocationSelect is not null', () => {
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

      const heading = queryByText('in_person_proofing.headings.po_search.location');
      const aboutMessage = queryByText(
        'in_person_proofing.body.location.po_search.po_search_about',
      );

      expect(heading).to.exist();
      expect(aboutMessage).to.exist();
      expect(
        queryByRole('heading', { name: 'in_person_proofing.headings.po_search.location' }),
      ).to.exist();
    });

    it('both do not render when handleLocationSelect is null', () => {
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

      const heading = queryByText('in_person_proofing.headings.po_search.location');
      const aboutMessage = queryByText(
        'in_person_proofing.body.location.po_search.po_search_about',
      );
      expect(heading).to.be.empty;
      expect(aboutMessage).to.be.empty;
    });
  });

  context('Address Search Label Text', () => {
    it('does not render when handleLocationSelect is not null', () => {
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

      const searchLabel = queryByText('in_person_proofing.headings.po_search.address_search_label');
      expect(searchLabel).to.be.empty;
    });

    it('renders when handleLocationSelect is null', () => {
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

      const searchLabel = queryByText(
        'in_person_proofing.body.location.po_search.address_search_label',
      );
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

    it('displays an error for unsupported characters in address field', async () => {
      const handleLocationsFound = sandbox.stub();
      const locationCache = new Map();
      const { findByText, findByLabelText } = render(
        <I18nContext.Provider
          value={
            new I18n({
              strings: {
                'in_person_proofing.form.address.errors.unsupported_chars':
                  'Our system cannot read the following characters: %{char_list} . Please try again using substitutes for those characters.',
              },
            })
          }
        >
          <SWRConfig value={{ provider: () => locationCache }}>
            <FullAddressSearch
              usStatesTerritories={usStatesTerritories}
              onFoundLocations={handleLocationsFound}
              locationsURL={locationsURL}
              registerField={() => undefined}
              handleLocationSelect={undefined}
              disabled={false}
            />
          </SWRConfig>
          ,
        </I18nContext.Provider>,
      );

      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.address_label'),
        '20, main',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.city_label'),
        'Endeavor',
      );
      await userEvent.selectOptions(
        await findByLabelText('in_person_proofing.body.location.po_search.state_label'),
        'DE',
      );
      await userEvent.type(
        await findByLabelText('in_person_proofing.body.location.po_search.zipcode_label'),
        '00010',
      );
      await userEvent.click(
        await findByText('in_person_proofing.body.location.po_search.search_button'),
      );

      const error = await findByText(
        'Our system cannot read the following characters: , . Please try again using substitutes for those characters.',
      );

      expect(error).to.exist();
      expect(locationCache.size).to.equal(1);
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
        http.post(locationsURL, () => HttpResponse.json([{ name: 'Baltimore' }])),
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

  context('Address Search with Results Section Heading', () => {
    let server: SetupServer;
    before(() => {
      server = setupServer(
        http.post(locationsURL, () => HttpResponse.json([{ name: 'Baltimore' }])),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('renders the results section heading when passed in', async () => {
      const handleLocationsFound = sandbox.stub();
      const onSelect = sinon.stub();
      const resultsSectionHeadingText = 'Mock Heading';
      const { findByText, getByLabelText, getByText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={onSelect}
            disabled={false}
            resultsSectionHeading={() => <h2>{resultsSectionHeadingText}</h2>}
          />
        </SWRConfig>,
      );

      await userEvent.type(
        getByLabelText('in_person_proofing.body.location.po_search.address_label'),
        '200 main',
      );
      await userEvent.type(
        getByLabelText('in_person_proofing.body.location.po_search.city_label'),
        'Endeavor',
      );
      await userEvent.selectOptions(
        getByLabelText('in_person_proofing.body.location.po_search.state_label'),
        'DE',
      );
      await userEvent.type(
        getByLabelText('in_person_proofing.body.location.po_search.zipcode_label'),
        '17201',
      );
      await userEvent.click(getByText('in_person_proofing.body.location.po_search.search_button'));

      expect(await findByText(resultsSectionHeadingText)).to.exist();
    });
  });
});
