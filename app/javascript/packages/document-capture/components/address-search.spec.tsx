import { render } from '@testing-library/react';
import { useSandbox } from '@18f/identity-test-helpers';
import userEvent from '@testing-library/user-event';
import AddressSearch from './address-search';

describe('AddressSearch', () => {
  const sandbox = useSandbox();

  it('fires the callback with correct input', async () => {
    const handleAddressFound = sandbox.stub();
    const { findByText, findByLabelText } = render(<AddressSearch onSearch={handleAddressFound} />);

    await userEvent.type(
      await findByLabelText('in_person_proofing.body.location.po_search.address_search_label'),
      '200 main',
    );
    await userEvent.click(
      await findByText('in_person_proofing.body.location.po_search.search_button'),
    );

    await expect(handleAddressFound).to.be.called();
  });
});
