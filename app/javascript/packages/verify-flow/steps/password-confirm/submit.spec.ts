import { useSandbox } from '@18f/identity-test-helpers';
import submit, { API_ENDPOINT } from './submit';

describe('submit', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox
      .stub(window, 'fetch')
      .withArgs(
        API_ENDPOINT,
        sandbox.match({ body: JSON.stringify({ user_bundle_token: '..', password: 'hunter2' }) }),
      )
      .resolves({
        json: () => Promise.resolve({ personal_key: '0000-0000-0000-0000' }),
      } as Response);
  });

  it('sends with password confirmation values', async () => {
    const patch = await submit({ userBundleToken: '..', password: 'hunter2' });

    expect(patch).to.deep.equal({ personalKey: '0000-0000-0000-0000' });
  });
});
