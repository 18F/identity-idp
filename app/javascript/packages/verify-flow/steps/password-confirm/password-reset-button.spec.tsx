import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import PasswordResetButton, { API_ENDPOINT } from './password-reset-button';

describe('PasswordResetButton', () => {
  const sandbox = useSandbox();

  const REDIRECT_URL = '/password_reset';

  before(() => {
    sandbox
      .stub(window, 'fetch')
      .withArgs(API_ENDPOINT)
      .resolves({
        status: 202,
        json: () => Promise.resolve({ redirect_url: REDIRECT_URL }),
      } as Response);
  });

  it('triggers password reset API call and redirects', (done) => {
    const { getByRole } = render(<PasswordResetButton onNavigate={() => done()} />);

    const button = getByRole('button');
    userEvent.click(button);
  });
});
