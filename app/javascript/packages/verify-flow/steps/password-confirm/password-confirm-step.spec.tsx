import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { accordion } from 'identity-style-guide';
import * as analytics from '@18f/identity-analytics';
import { useSandbox, usePropertyValue } from '@18f/identity-test-helpers';
import { t, i18n } from '@18f/identity-i18n';
import PasswordConfirmStep from './password-confirm-step';

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

  describe('forgot password', () => {
    usePropertyValue(i18n, 'strings', {
      'idv.forgot_password.link_html': 'Forgot password? %{link}',
      'idv.forgot_password.warnings': [],
    });

    it('navigates to forgot password subpage', async () => {
      const { getByRole } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

      await userEvent.click(getByRole('link', { name: 'idv.forgot_password.link_text' }));

      expect(window.location.pathname).to.equal('/password_confirm/forgot_password');
    });

    it('navigates back from forgot password subpage', async () => {
      const { getByRole } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

      await userEvent.click(getByRole('link', { name: 'idv.forgot_password.link_text' }));
      await userEvent.click(getByRole('link', { name: 'idv.forgot_password.try_again' }));

      expect(window.location.pathname).to.equal('/password_confirm');
    });
  });

  describe('alert', () => {
    context('without phone value', () => {
      it('does not render success alert', () => {
        const { queryByRole } = render(<PasswordConfirmStep {...DEFAULT_PROPS} />);

        expect(queryByRole('status')).to.not.exist();
      });
    });

    context('with phone value', () => {
      it('renders success alert', () => {
        const { queryByRole } = render(
          <PasswordConfirmStep {...DEFAULT_PROPS} value={{ phone: '5135551234' }} />,
        );

        const status = queryByRole('status')!;

        expect(status).to.exist();
        expect(status.textContent).to.equal('idv.messages.review.info_verified_html');
      });

      context('with other errors', () => {
        it('does not render success alert', () => {
          const { queryByRole } = render(
            <PasswordConfirmStep
              {...DEFAULT_PROPS}
              value={{ phone: '5135551234' }}
              errors={[{ error: new Error() }]}
            />,
          );

          expect(queryByRole('status')).to.not.exist();
        });
      });
    });

    context('with errors', () => {
      it('renders error messages', () => {
        const { queryByRole } = render(
          <PasswordConfirmStep {...DEFAULT_PROPS} errors={[{ error: new Error('Uh oh!') }]} />,
        );

        const alert = queryByRole('alert')!;

        expect(alert).to.exist();
        expect(alert.textContent).to.equal('Uh oh!');
      });
    });
  });
});
