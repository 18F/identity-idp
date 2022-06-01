import { FormError } from '@18f/identity-form-steps';
import { useSandbox } from '@18f/identity-test-helpers';
import submit, { API_ENDPOINT } from './submit';

describe('submit', () => {
  const sandbox = useSandbox();

  context('with successful submission', () => {
    beforeEach(() => {
      sandbox
        .stub(window, 'fetch')
        .withArgs(
          API_ENDPOINT,
          sandbox.match({ body: JSON.stringify({ user_bundle_token: '..', password: 'hunter2' }) }),
        )
        .resolves({
          json: () =>
            Promise.resolve({
              personal_key: '0000-0000-0000-0000',
              completion_url: 'http://example.com',
            }),
        } as Response);
    });

    it('sends with password confirmation values', async () => {
      const patch = await submit({ userBundleToken: '..', password: 'hunter2' });

      expect(patch).to.deep.equal({
        personalKey: '0000-0000-0000-0000',
        completionURL: 'http://example.com',
      });
    });
  });

  context('error submission', () => {
    beforeEach(() => {
      sandbox
        .stub(window, 'fetch')
        .withArgs(
          API_ENDPOINT,
          sandbox.match({ body: JSON.stringify({ user_bundle_token: '..', password: 'hunter2' }) }),
        )
        .resolves({
          json: () => Promise.resolve({ error: { password: ['incorrect password'] } }),
        } as Response);
    });

    it('throws error for the offending field', async () => {
      const didError = await submit({ userBundleToken: '..', password: 'hunter2' }).catch(
        (error: FormError) => {
          expect(error.field).to.equal('password');
          expect(error.message).to.equal('incorrect password');
          return true;
        },
      );

      expect(didError).to.be.true();
    });
  });
});
