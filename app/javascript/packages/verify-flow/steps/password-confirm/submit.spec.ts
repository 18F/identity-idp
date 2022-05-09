import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import submit from './submit';

describe('submit', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();

  beforeEach(() => {
    sandbox
      .stub(window, 'fetch')
      .withArgs(
        'https://example.com/api/personal_key',
        sandbox.match({ body: JSON.stringify({ user_bundle_token: '..', password: 'hunter2' }) }),
      )
      .resolves({
        json: () => Promise.resolve({ personal_key: '0000-0000-0000-0000' }),
      } as Response);

    defineProperty(window, 'location', {
      value: {
        href: 'https://example.com/personal_key',
        pathname: '/personal_key',
      },
    });
  });

  it('sends with password confirmation values', async () => {
    const { personalKey } = await submit({ userBundleToken: '..', password: 'hunter2' });

    expect(personalKey).to.equal('0000-0000-0000-0000');
  });
});
