import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useDefineProperty, useSandbox } from '@18f/identity-test-helpers';
import PasswordResetButton, { API_ENDPOINT } from './password-reset-button';

describe('PasswordResetButton', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();

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

  it('triggers password reset API call and redirects', () => {
    const { getByRole } = render(<PasswordResetButton />);

    return new Promise<void>((resolve) => {
      defineProperty(window, 'location', {
        value: {
          set href(nextHref) {
            expect(nextHref).to.equal(REDIRECT_URL);
            resolve();
          },
        },
      });

      const button = getByRole('button');
      userEvent.click(button);
    });
  });
});
