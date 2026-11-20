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
            usesErrorComponent
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
            usesErrorComponent
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
            usesErrorComponent
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
            usesErrorComponent
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
            usesErrorComponent
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
              usesErrorComponent
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
            usesErrorComponent
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
            usesErrorComponent
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

  context('when address search errors', () => {
    let server: SetupServer;
    before(() => {
      server = setupServer(http.post(locationsURL, () => HttpResponse.error()));
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('shows error component', async () => {
      const handleLocationsFound = sandbox.stub();
      const { findByText, getByText, getByLabelText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={undefined}
            disabled={false}
            usesErrorComponent
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

      const errorComponent = await findByText(
        'in_person_proofing.body.location.po_search.usps_facilities_api_error_header',
      );
      expect(errorComponent).to.exist();
    });

    it('shows continue button', async () => {
      const handleLocationsFound = sandbox.stub();
      const { findByText, getByText, getByLabelText } = render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={handleLocationsFound}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={undefined}
            disabled={false}
            usesErrorComponent
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

      const errorBtn = await findByText(
        'in_person_proofing.body.location.po_search.continue_button',
      );
      expect(errorBtn).to.exist();
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
            usesErrorComponent
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
            usesErrorComponent
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

  context('in the NDS layout', () => {
    const POST_OFFICE = {
      address: '4163 E Camelback Road',
      city: 'Phoenix',
      distance: '2.4 mi',
      name: 'Camelback',
      saturday_hours: '8:30 AM - 5:00 PM',
      state: 'AZ',
      sunday_hours: 'Closed',
      weekday_hours: '9:00 AM - 12:00 PM',
      zip_code_4: '8993',
      zip_code_5: '85017',
    };

    let server: SetupServer;
    before(() => {
      server = setupServer();
      server.listen();
    });

    afterEach(() => {
      server.resetHandlers();
    });

    after(() => {
      server.close();
    });

    function renderNDS(props = {}) {
      return render(
        <SWRConfig value={{ provider: () => new Map() }}>
          <FullAddressSearch
            usStatesTerritories={usStatesTerritories}
            onFoundLocations={sandbox.stub()}
            locationsURL={locationsURL}
            registerField={() => undefined}
            handleLocationSelect={sinon.stub()}
            disabled={false}
            usesErrorComponent
            nds
            {...props}
          />
        </SWRConfig>,
      );
    }

    async function fillAddress({ getByLabelText }, zipCode = '85284') {
      await userEvent.type(
        getByLabelText('in_person_proofing.body.location.po_search.address_label'),
        '4729 North Wellington Drive',
      );
      await userEvent.type(
        getByLabelText('in_person_proofing.body.location.po_search.city_label'),
        'Phoenix',
      );
      await userEvent.selectOptions(
        getByLabelText('in_person_proofing.body.location.po_search.state_label'),
        'DE',
      );
      await userEvent.type(getByLabelText('nds.post_office.search.zipcode_label'), zipCode);
    }

    it('renders the NDS heading and subtitle instead of the default copy', () => {
      const { getByRole, getByText, queryByText, container } = renderNDS();

      expect(container.querySelector('section.auth.auth--form-page')).to.exist();
      expect(getByRole('heading', { level: 1, name: 'nds.post_office.search.heading' })).to.exist();
      expect(
        getByText('nds.post_office.search.subtitle').classList.contains('auth__intro-description'),
      ).to.be.true();
      expect(queryByText('in_person_proofing.headings.po_search.location')).not.to.exist();
      expect(
        queryByText('in_person_proofing.body.location.po_search.po_search_about'),
      ).not.to.exist();
    });

    it('renders floating-label inputs and the visible state select', () => {
      const { getByLabelText } = renderNDS();

      ['address_label', 'city_label'].forEach((key) => {
        const input = getByLabelText(`in_person_proofing.body.location.po_search.${key}`);
        expect(input.classList.contains('usa-input__control--floating')).to.be.true();
      });
      expect(
        getByLabelText('nds.post_office.search.zipcode_label').classList.contains(
          'usa-input__control--floating',
        ),
      ).to.be.true();
      expect(
        getByLabelText('in_person_proofing.body.location.po_search.state_label').classList.contains(
          'usa-select',
        ),
      ).to.be.true();
    });

    it('keeps Search disabled until every field is valid', async () => {
      const utils = renderNDS();
      const search = utils.getByRole('button', {
        name: 'in_person_proofing.body.location.po_search.search_button',
      }) as HTMLButtonElement;

      expect(search.disabled).to.be.true();
      expect(search.classList.contains('usa-button--lg')).to.be.true();

      await fillAddress(utils, '852');
      expect(search.disabled).to.be.true();

      await userEvent.type(utils.getByLabelText('nds.post_office.search.zipcode_label'), '84');
      expect(search.disabled).to.be.false();
    });

    it('shows a field error when leaving a field with an invalid value', async () => {
      const { getByLabelText, findByText } = renderNDS();

      await userEvent.type(getByLabelText('nds.post_office.search.zipcode_label'), '852');
      await userEvent.tab();

      expect(await findByText('idv.errors.pattern_mismatch.zipcode_five')).to.exist();
      expect(
        getByLabelText('nds.post_office.search.zipcode_label').getAttribute('aria-invalid'),
      ).to.equal('true');
    });

    it('shows the spinner in place of the label while searching', async () => {
      let respond: () => void = () => {};
      server.use(
        http.post(
          locationsURL,
          () =>
            new Promise((resolve) => {
              respond = () => resolve(HttpResponse.json([POST_OFFICE]));
            }),
        ),
      );
      const utils = renderNDS();
      await fillAddress(utils);
      const search = utils.getByRole('button', {
        name: 'in_person_proofing.body.location.po_search.search_button',
      });

      await userEvent.click(search);

      expect(
        await utils.findByText('in_person_proofing.body.location.po_search.is_searching_message'),
      ).to.exist();
      expect(search.querySelector('.nds-spinner[aria-hidden="true"]')).to.exist();
      expect(search.classList.contains('usa-button--active')).to.be.true();
      expect(search.querySelector('.usa-sr-only')!.textContent).to.equal(
        'in_person_proofing.body.location.po_search.search_button',
      );

      respond();
      await utils.findByRole('heading', { level: 2 });
      expect(search.querySelector('.nds-spinner')).not.to.exist();
    });

    it('renders the results below a divider in an elevated card', async () => {
      server.use(http.post(locationsURL, () => HttpResponse.json([POST_OFFICE, POST_OFFICE])));
      const utils = renderNDS();
      await fillAddress(utils);
      await userEvent.click(
        utils.getByRole('button', {
          name: 'in_person_proofing.body.location.po_search.search_button',
        }),
      );

      const heading = await utils.findByRole('heading', {
        level: 2,
        name: 'in_person_proofing.body.location.po_search.results_description',
      });
      expect(heading.classList.contains('card__title')).to.be.true();
      expect(heading.parentElement!.getAttribute('role')).to.equal('status');
      expect(heading.parentElement!.previousElementSibling!.matches('hr.divider')).to.be.true();
      expect(
        utils.container.querySelectorAll('.card.card--elevated li.location-collection__item'),
      ).to.have.lengthOf(2);
      expect(
        utils.queryByText('in_person_proofing.body.location.po_search.results_instructions'),
      ).not.to.exist();
    });

    it('renders the NDS error alert and a Continue button when the search fails', async () => {
      server.use(http.post(locationsURL, () => HttpResponse.error()));
      const utils = renderNDS();
      await fillAddress(utils);
      await userEvent.click(
        utils.getByRole('button', {
          name: 'in_person_proofing.body.location.po_search.search_button',
        }),
      );

      const alert = await utils.findByRole('alert');
      expect(alert.classList.contains('usa-alert--error')).to.be.true();
      expect(alert.textContent).to.contain(
        'in_person_proofing.body.location.po_search.usps_facilities_api_error_header',
      );
      const continueButton = utils.getByRole('button', {
        name: 'in_person_proofing.body.location.po_search.continue_button',
      }) as HTMLButtonElement;
      expect(continueButton.disabled).to.be.false();
    });
  });
});
