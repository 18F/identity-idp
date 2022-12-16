import { render } from '@testing-library/react';
import { useSandbox } from '@18f/identity-test-helpers';
import * as requester from '@18f/identity-request';
import userEvent from '@testing-library/user-event';
import AddressSearch from './address-search';

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

describe('AddressSearch', () => {
  const sandbox = useSandbox();

  it('searches for an address', async () => {
    const { findByText, findByLabelText } = render(
      <AddressSearch registerField={() => undefined} />,
    );

    sandbox.stub(requester, 'request').callsFake(() => Promise.resolve(DEFAULT_RESPONSE));

    await userEvent.type(
      await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
      '100 main',
    );
    await userEvent.click(
      await findByText('in_person_proofing.body.location.po_search.search_button'),
    );

    expect(requester.request).to.have.been.called();
  });

  it('fires the callback with correct input', async () => {
    const handleAddressFound = sandbox.stub();
    const { findByText, findByLabelText } = render(
      <AddressSearch registerField={() => undefined} onAddressFound={handleAddressFound} />,
    );

    sandbox.stub(requester, 'request').callsFake(() => Promise.resolve(DEFAULT_RESPONSE));

    await userEvent.type(
      await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
      '100 main',
    );
    await userEvent.click(
      await findByText('in_person_proofing.body.location.po_search.search_button'),
    );

    expect(handleAddressFound).to.have.been.calledWith(DEFAULT_RESPONSE[0]);
  });

  it('validates input and shows inline error', async () => {
    const { findByText } = render(<AddressSearch registerField={() => undefined} />);

    sandbox.stub(requester, 'request').callsFake(() => Promise.resolve(DEFAULT_RESPONSE));

    await userEvent.click(
      await findByText('in_person_proofing.body.location.po_search.search_button'),
    );

    await findByText('in_person_proofing.body.location.inline_error');
  });
});
