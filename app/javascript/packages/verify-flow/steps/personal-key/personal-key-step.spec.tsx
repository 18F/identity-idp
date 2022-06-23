import sinon from 'sinon';
import * as analytics from '@18f/identity-analytics';
import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import PersonalKeyStep from './personal-key-step';
import { AddressVerificationMethodContextProvider } from '../../context/address-verification-method-context';

describe('PersonalKeyStep', () => {
  const sandbox = sinon.createSandbox();
  const DEFAULT_PROPS = {
    onChange() {},
    onError() {},
    errors: [],
    toPreviousStep() {},
    registerField: () => () => {},
    unknownFieldErrors: [],
    value: { personalKey: '' },
  };

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
  });

  afterEach(() => {
    sandbox.restore();
  });

  it('calls trackEvent when user clicks on "Download" button', async () => {
    const { getByText } = render(<PersonalKeyStep {...DEFAULT_PROPS} />);

    const button = getByText('forms.backup_code.download');
    button.addEventListener('click', (event) => event.preventDefault());
    await userEvent.click(button);
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: download personal key');
  });

  it('calls trackEvent when user clicks on "Clipboard" button', async () => {
    const { getByText } = render(<PersonalKeyStep {...DEFAULT_PROPS} />);

    await userEvent.click(getByText('components.clipboard_button.label'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: copy personal key');
  });

  it('calls trackEvent when user clicks on "Print" button', async () => {
    window.print = () => {};

    const { getByText } = render(<PersonalKeyStep {...DEFAULT_PROPS} />);

    await userEvent.click(getByText('components.print_button.label'));
    expect(analytics.trackEvent).to.have.been.calledWith('IdV: print personal key');
  });

  context('with gpo as address verification method', () => {
    it('renders success alert', () => {
      const { getByRole } = render(
        <AddressVerificationMethodContextProvider initialMethod="gpo">
          <PersonalKeyStep {...DEFAULT_PROPS} />
        </AddressVerificationMethodContextProvider>,
      );

      const status = getByRole('status');

      expect(status.textContent).to.equal('idv.messages.mail_sent');
    });
  });

  context('with phone as address verification method', () => {
    it('renders success alert', () => {
      const { getByRole } = render(
        <AddressVerificationMethodContextProvider initialMethod="phone">
          <PersonalKeyStep {...DEFAULT_PROPS} />
        </AddressVerificationMethodContextProvider>,
      );

      const status = getByRole('status');

      expect(status.textContent).to.equal('idv.messages.confirm');
    });
  });
});
