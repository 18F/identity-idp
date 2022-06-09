import { useContext } from 'react';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import AddressVerificationMethodContext, {
  AddressVerificationMethodContextProvider,
} from './address-verification-method-context';

describe('AddressVerificationMethodContextProvider', () => {
  function TestComponent() {
    const { addressVerificationMethod, setAddressVerificationMethod } = useContext(
      AddressVerificationMethodContext,
    );
    return (
      <>
        <div>Current value: {String(addressVerificationMethod)}</div>
        <button
          type="button"
          onClick={() =>
            setAddressVerificationMethod(addressVerificationMethod === 'phone' ? 'gpo' : 'phone')
          }
        >
          Update
        </button>
      </>
    );
  }

  it('initializes with default value', () => {
    const { getByText } = render(
      <AddressVerificationMethodContextProvider>
        <TestComponent />
      </AddressVerificationMethodContextProvider>,
    );

    expect(getByText('Current value: null')).to.exist();
  });

  it('can be overridden with an initial method', () => {
    const { getByText } = render(
      <AddressVerificationMethodContextProvider initialMethod="gpo">
        <TestComponent />
      </AddressVerificationMethodContextProvider>,
    );

    expect(getByText('Current value: gpo')).to.exist();
  });

  it('exposes a setter to change the value', async () => {
    const { getByText } = render(
      <AddressVerificationMethodContextProvider initialMethod="gpo">
        <TestComponent />
      </AddressVerificationMethodContextProvider>,
    );

    await userEvent.click(getByText('Update'));

    expect(getByText('Current value: phone')).to.exist();
  });
});
