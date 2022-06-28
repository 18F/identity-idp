import { render } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { useSandbox } from '@18f/identity-test-helpers';
import PasswordResetButton, { API_ENDPOINT } from './password-reset-button';
import * as api from '../../services/api';
import FlowContext, { FlowContextValue } from '../../context/flow-context';

describe('PasswordResetButton', () => {
  const sandbox = useSandbox();

  const REDIRECT_URL = '/password_reset';

  before(() => {
    sandbox
      .stub(api, 'post')
      .withArgs(API_ENDPOINT, sandbox.match.any)
      .resolves({ redirect_url: REDIRECT_URL });
  });

  it('triggers password reset API call and redirects', (done) => {
    function onComplete({ completionURL }) {
      let error;

      try {
        expect(completionURL).to.equal(REDIRECT_URL);
      } catch (assertionError) {
        error = assertionError;
      }

      done(error);
    }
    const { getByRole } = render(
      <FlowContext.Provider value={{ onComplete } as FlowContextValue}>
        <PasswordResetButton />
      </FlowContext.Provider>,
    );

    const button = getByRole('button');
    userEvent.click(button);
  });
});
