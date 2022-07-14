import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { computeAccessibleDescription } from 'dom-accessibility-api';
import { accordion } from 'identity-style-guide';
import type { SinonSpy } from 'sinon';
import * as analytics from '@18f/identity-analytics';
import { useSandbox, usePropertyValue } from '@18f/identity-test-helpers';
import { FormSteps } from '@18f/identity-form-steps';
import { t, i18n } from '@18f/identity-i18n';
import PasswordConfirmStep from './password-confirm-step';
import submit, { PasswordSubmitError } from './submit';
import { AddressVerificationMethodContextProvider } from '../../context/address-verification-method-context';

describe('PasswordConfirmStep', () => {
  const sandbox = useSandbox();
  const DEFAULT_PROPS = {
    onChange() {},
    onError() {},
    errors: [],
    toPreviousStep() {},
    registerField: () => () => {},
    unknownFieldErrors: [],
    value: {},
  };

  before(() => {
    accordion.on();
  });

  beforeEach(() => {
    sandbox.spy(analytics, 'trackEvent');
  });

  after(() => {
    accordion.off();
  });

  it('has a collapsed accordion by default', () => {
    const { getByText } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

    const button = getByText(t('idv.messages.review.intro'));
    expect(button.getAttribute('aria-expanded')).to.eq('false');
  });

  it('expands accordion when the accordion is clicked on', async () => {
    const { getByText } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

    const button = getByText(t('idv.messages.review.intro'));
    await userEvent.click(button);
    expect(button.getAttribute('aria-expanded')).to.eq('true');
  });

  it('displays user information when the accordion is clicked on', async () => {
    const { getByText } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

    const button = getByText(t('idv.messages.review.intro'));
    await userEvent.click(button);

    expect(getByText('idv.review.full_name')).to.exist();
    expect(getByText('idv.review.mailing_address')).to.exist();
  });

  it('validates missing password', async () => {
    const { getByRole, getByLabelText, queryByRole } = render(
      <FormSteps steps={[{ name: 'password_confirm', form: PasswordConfirmStep, submit }]} />,
    );

    await userEvent.click(getByRole('button', { name: 'forms.buttons.continue' }));

    // There should not be a top-level error alert, only field-specific.
    expect(queryByRole('alert')).to.not.exist();
    const input = getByLabelText('components.password_toggle.label');
    const description = computeAccessibleDescription(input);
    expect(description).to.equal('simple_form.required.text');
  });

  it('validates incorrect password', async () => {
    sandbox.stub(window, 'fetch').resolves({
      status: 400,
      json: () => Promise.resolve({ errors: { password: ['Incorrect password'] } }),
    } as Response);

    const { getByRole, findByRole, getByLabelText } = render(
      <FormSteps steps={[{ name: 'password_confirm', form: PasswordConfirmStep, submit }]} />,
    );

    sandbox.spy(Element.prototype, 'scrollIntoView');
    const continueButton = getByRole('button', { name: 'forms.buttons.continue' });

    await userEvent.type(getByLabelText('components.password_toggle.label'), 'password');
    await userEvent.click(continueButton);

    // There should not be a field-specific error, only a top-level alert.
    const alert = await findByRole('alert');
    expect(Element.prototype.scrollIntoView).to.have.been.calledOnce();
    const { thisValue: scrollElement } = (Element.prototype.scrollIntoView as SinonSpy).getCall(0);
    expect((scrollElement as Element).contains(alert)).to.be.true();
    expect(alert.textContent).to.equal('Incorrect password');
    const input = getByLabelText('components.password_toggle.label');
    const description = computeAccessibleDescription(input);
    expect(description).to.be.empty();

    await userEvent.click(continueButton);
    expect(Element.prototype.scrollIntoView).to.have.been.calledTwice();
  });

  describe('forgot password', () => {
    usePropertyValue(i18n, 'strings', {
      'idv.forgot_password.link_html': 'Forgot password? %{link}',
      'idv.forgot_password.warnings': [],
    });

    it('navigates to forgot password subpage', async () => {
      const { getByRole } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

      await userEvent.click(getByRole('link', { name: 'idv.forgot_password.link_text' }));

      expect(window.location.pathname).to.equal('/password_confirm/forgot_password');
      expect(analytics.trackEvent).to.have.been.calledWith('IdV: forgot password visited');
      expect(analytics.trackEvent).not.to.have.been.calledWith('IdV: password confirm visited');
    });

    it('navigates back from forgot password subpage', async () => {
      const { getByRole } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

      await userEvent.click(getByRole('link', { name: 'idv.forgot_password.link_text' }));
      await userEvent.click(getByRole('link', { name: 'idv.forgot_password.try_again' }));

      expect(window.location.pathname).to.equal('/password_confirm');
      expect(analytics.trackEvent).to.have.been.calledWith('IdV: forgot password visited');
      expect(analytics.trackEvent).to.have.been.calledWith('IdV: password confirm visited');
    });
  });

  describe('alert', () => {
    context('with gpo as address verification method', () => {
      it('does not render success alert', () => {
        const { queryByRole } = render(
          <AddressVerificationMethodContextProvider initialMethod="gpo">
            <PasswordConfirmStep {...DEFAULT_PROPS} />
          </AddressVerificationMethodContextProvider>,
        );

        expect(queryByRole('status')).to.not.exist();
      });
    });

    context('with phone as address verification method', () => {
      it('renders success alert', () => {
        const { queryByRole } = render(
          <AddressVerificationMethodContextProvider initialMethod="phone">
            <PasswordConfirmStep {...DEFAULT_PROPS} />
          </AddressVerificationMethodContextProvider>,
        );

        const status = queryByRole('status')!;

        expect(status).to.exist();
        expect(status.textContent).to.equal('idv.messages.review.info_verified_html');
      });
    });

    context('with errors', () => {
      it('renders error messages', () => {
        const { queryByRole } = render(
          <PasswordConfirmStep
            {...DEFAULT_PROPS}
            errors={[
              { error: new Error('Uh oh!') },
              { error: new PasswordSubmitError('Submit error') },
            ]}
          />,
        );

        const alert = queryByRole('alert')!;

        expect(alert).to.exist();
        expect(alert.textContent).to.equal('Submit error');
      });
    });
  });
});
