import upload, {
  UploadFormEntriesError,
  UploadFormEntryError,
  toFormData,
  toFormEntryError,
} from '@18f/identity-document-capture/services/upload';
import { useSandbox } from '@18f/identity-test-helpers';

describe('document-capture/services/upload', () => {
  const sandbox = useSandbox();

  describe('toFormData', () => {
    it('returns FormData representation of object', () => {
      const result = toFormData({ foo: 'bar' });

      expect(result).to.be.instanceOf(window.FormData);
      expect(/** @type {FormData} */ (result).get('foo')).to.equal('bar');
    });

    it('omits undefined values', () => {
      const result = toFormData({ foo: 'bar', bar: null, baz: undefined });

      expect([...result.keys()]).to.have.members(['foo', 'bar']);
    });
  });

  describe('toFormEntryError', () => {
    it('maps server response error to UploadFormEntryError', () => {
      const result = toFormEntryError({ field: 'front', message: 'Image has glare' });

      expect(result).to.be.instanceof(UploadFormEntryError);
      expect(result.field).to.equal('front');
      expect(result.message).to.equal('Image has glare');
    });
  });

  it('submits payload to endpoint successfully', async () => {
    const endpoint = 'https://example.com';

    sandbox.stub(window, 'fetch').callsFake((url, init) => {
      expect(url).to.equal(endpoint);
      expect(init.headers).to.be.empty();
      expect(init.body).to.be.instanceOf(window.FormData);
      expect(init.body.get('foo')).to.equal('bar');

      return Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: true,
          status: 200,
          url: endpoint,
          json: () =>
            Promise.resolve({
              success: true,
            }),
        }),
      );
    });

    const result = await upload({ foo: 'bar' }, { endpoint, csrf: null });
    expect(result).to.deep.equal({ success: true, isPending: false });
  });

  context('with csrf token', () => {
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
            url: endpoint,
            json: () =>
              Promise.resolve({
                success: true,
              }),
          }),
        );
      });

      const result = await upload({ foo: 'bar' }, { endpoint, csrf });
      expect(result).to.deep.equal({ success: true, isPending: false });
    });
  });

  it('handles redirect', async () => {
    const endpoint = 'https://example.com';
    const csrf = 'TYsqyyQ66Y';

    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: true,
          status: 200,
          url: '#teapot',
          text: () => Promise.resolve(''),
        }),
      ),
    );

    let assertOnHashChange;

    // `Promise.race` because the `upload` promise should never resolve in case of a redirect.
    await Promise.race([
      new Promise((resolve) => {
        assertOnHashChange = () => {
          expect(window.location.hash).to.equal('#teapot');
          resolve();
        };

        window.addEventListener('hashchange', assertOnHashChange);
      }),
      upload({}, { endpoint, csrf }).then(() => {
        throw new Error('Unexpected upload resolution during redirect.');
      }),
    ]);

    window.removeEventListener('hashchange', assertOnHashChange);
  });

  it('handles pending success success', async () => {
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
          status: 202,
          url: endpoint,
          json: () =>
            Promise.resolve({
              success: true,
            }),
        }),
      );
    });

    const result = await upload({ foo: 'bar' }, { endpoint, csrf });
    expect(result).to.deep.equal({ success: true, isPending: true });
  });

  it('handles invalid request', async () => {
    const endpoint = 'https://example.com';

    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: false,
          status: 400,
          url: endpoint,
          json: () =>
            Promise.resolve({
              success: false,
              errors: [
                { field: 'front', message: 'Please fill in this field' },
                { field: 'back', message: 'Please fill in this field' },
              ],
              remaining_attempts: 3,
              hints: true,
              ocr_pii: { first_name: 'Fakey', last_name: 'McFakerson', dob: '1938-10-06' },
            }),
        }),
      ),
    );

    try {
      await upload({}, { endpoint, csrf: 'TYsqyyQ66Y' });
      throw new Error('This is a safeguard and should never be reached, since upload should error');
    } catch (error) {
      expect(error).to.be.instanceOf(UploadFormEntriesError);
      expect(error.remainingAttempts).to.equal(3);
      expect(error.hints).to.be.true();
      expect(error.pii).to.deep.equal({
        first_name: 'Fakey',
        last_name: 'McFakerson',
        dob: '1938-10-06',
      });
      expect(error.formEntryErrors[0]).to.be.instanceOf(UploadFormEntryError);
      expect(error.formEntryErrors[0].field).to.equal('front');
      expect(error.formEntryErrors[0].message).to.equal('Please fill in this field');
      expect(error.formEntryErrors[1]).to.be.instanceOf(UploadFormEntryError);
      expect(error.formEntryErrors[1].field).to.equal('back');
      expect(error.formEntryErrors[1].message).to.equal('Please fill in this field');
    }
  });

  it('redirects error', async () => {
    const endpoint = 'https://example.com';

    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: false,
          status: 418,
          statusText: "I'm a teapot",
          url: endpoint,
          json: () =>
            Promise.resolve({
              success: false,
              redirect: '#teapot',
            }),
        }),
      ),
    );

    let assertOnHashChange;

    // `Promise.race` because the `upload` promise should never resolve in case of a redirect.
    await Promise.race([
      new Promise((resolve) => {
        assertOnHashChange = () => {
          expect(window.location.hash).to.equal('#teapot');
          resolve();
        };

        window.addEventListener('hashchange', assertOnHashChange);
      }),
      upload({}, { endpoint, csrf: 'TYsqyyQ66Y' }).then(() => {
        throw new Error('Unexpected upload resolution during redirect.');
      }),
    ]);

    window.removeEventListener('hashchange', assertOnHashChange);
  });

  it('throws unhandled response', async () => {
    const endpoint = 'https://example.com';

    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        /** @type {Partial<Response>} */ ({
          ok: false,
          status: 500,
          statusText: 'Server error',
          url: endpoint,
        }),
      ),
    );

    try {
      await upload({}, { endpoint, csrf: 'TYsqyyQ66Y' });
    } catch (error) {
      expect(error).to.be.instanceof(Error);
      expect(error.message).to.equal('Server error');
    }
  });
});
