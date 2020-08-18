import upload, { toFormData } from '@18f/identity-document-capture/services/upload';
import { useSandbox } from '../../../support/sinon';

describe('document-capture/services/upload', () => {
  const sandbox = useSandbox();

  describe('toFormData', () => {
    it('returns FormData representation of object', () => {
      const result = toFormData({ foo: 'bar' });

      expect(result).to.be.instanceOf(window.FormData);
      expect(/** @type {FormData} */ (result).get('foo')).to.equal('bar');
    });
  });

  it('submits payload to endpoint successfully', async () => {
    const endpoint = 'https://example.com';
    const csrf = 'TYsqyyQ66Y';

    sandbox.stub(window, 'fetch').callsFake((url, init) => {
      expect(url).to.equal(endpoint);
      expect(init.headers['X-CSRF-Token']).to.equal(csrf);
      expect(init.body).to.be.instanceOf(window.FormData);
      expect(init.body.get('foo')).to.equal('bar');

      return Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: true,
          status: 200,
          json: () =>
            Promise.resolve({
              success: true,
            }),
        }),
      );
    });

    const result = await upload({ foo: 'bar' }, { endpoint, csrf });
    expect(result).to.deep.equal({ success: true });
  });

  it('handles invalid request', async () => {
    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: false,
          status: 400,
          json: () =>
            Promise.resolve({
              success: false,
              errors: ['Foo missing', 'Baz missing'],
            }),
        }),
      ),
    );

    try {
      await upload({}, { endpoint: 'https://example.com', csrf: 'TYsqyyQ66Y' });
    } catch (error) {
      expect(error.message).to.equal('Foo missing, Baz missing');
    }
  });

  it('throws unhandled response', async () => {
    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: false,
          status: 500,
          statusText: 'Server error',
        }),
      ),
    );

    try {
      await upload({}, { endpoint: 'https://example.com', csrf: 'TYsqyyQ66Y' });
    } catch (error) {
      expect(error.message).to.equal('Server error');
    }
  });
});
