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

  it('triggers password reset API call and redirects', async () => {
    const onComplete = sandbox.stub() as FlowContextValue['onComplete'];

    const { getByRole } = render(
      <FlowContext.Provider value={{ onComplete } as FlowContextValue}>
        <PasswordResetButton />
      </FlowContext.Provider>,
    );

    const button = getByRole('button');
    await Promise.all([
      userEvent.click(button),
      expect(onComplete).to.eventually.be.calledWith({ completionURL: REDIRECT_URL }),
    ]);
  });
});
