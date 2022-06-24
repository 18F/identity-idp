import { FormError } from '@18f/identity-form-steps';
import { useSandbox } from '@18f/identity-test-helpers';
import submit, { API_ENDPOINT } from './submit';
import * as api from '../../services/api';

describe('submit', () => {
  const sandbox = useSandbox();

  context('with successful submission', () => {
    beforeEach(() => {
      sandbox
        .stub(api, 'post')
        .withArgs(API_ENDPOINT, {
          user_bundle_token: '..',
          password: 'hunter2',
        })
        .resolves({
          personal_key: '0000-0000-0000-0000',
          completion_url: 'http://example.com',
        });
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
        .stub(api, 'post')
        .withArgs(API_ENDPOINT, {
          user_bundle_token: '..',
          password: 'hunter2',
        })
        .resolves({ errors: { password: ['incorrect password'] } });
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
