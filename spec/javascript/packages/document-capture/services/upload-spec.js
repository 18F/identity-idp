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

    sandbox.stub(global, 'fetch').callsFake((url, init) => {
      expect(url).to.equal(endpoint);
      expect(init.body).to.be.instanceOf(window.FormData);
      expect(init.body.get('foo')).to.equal('bar');

      const response = new Response(JSON.stringify({ success: true }));
      sandbox.stub(response, 'url').get(() => endpoint);
      return Promise.resolve(response);
    });

    const result = await upload({ foo: 'bar' }, { endpoint });
    expect(result).to.deep.equal({ success: true, isPending: false });
  });

  it('handles redirect', async () => {
    const endpoint = 'https://example.com';

    const response = new Response('');
    sandbox.stub(response, 'url').get(() => '#teapot');
    sandbox.stub(global, 'fetch').callsFake(() => Promise.resolve(response));

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
      upload({}, { endpoint }).then(() => {
        throw new Error('Unexpected upload resolution during redirect.');
      }),
    ]);

    window.removeEventListener('hashchange', assertOnHashChange);
  });

  it('handles pending success', async () => {
    const endpoint = 'https://example.com';

    sandbox.stub(global, 'fetch').callsFake((url, init) => {
      expect(url).to.equal(endpoint);
      expect(init.body).to.be.instanceOf(window.FormData);
      expect(init.body.get('foo')).to.equal('bar');

      const response = new Response(
        JSON.stringify({
          success: true,
        }),
        { status: 202 },
      );
      sandbox.stub(response, 'url').get(() => endpoint);
      return Promise.resolve(response);
    });

    const result = await upload({ foo: 'bar' }, { endpoint });
    expect(result).to.deep.equal({ success: true, isPending: true });
  });

  it('handles invalid request', async () => {
    const endpoint = 'https://example.com';

    const response = new Response(
      JSON.stringify({
        success: false,
        errors: [
          { field: 'front', message: 'Please fill in this field' },
          { field: 'back', message: 'Please fill in this field' },
        ],
        remaining_attempts: 3,
        hints: true,
        result_failed: true,
        ocr_pii: { first_name: 'Fakey', last_name: 'McFakerson', dob: '1938-10-06' },
      }),
      { status: 400 },
    );
    sandbox.stub(response, 'url').get(() => endpoint);
    sandbox.stub(global, 'fetch').callsFake(() => Promise.resolve(response));

    try {
      await upload({}, { endpoint });
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
      expect(error.isFailedResult).to.be.true();
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

    const response = new Response(
      JSON.stringify({
        success: false,
        redirect: '#teapot',
      }),
      { status: 418 },
    );
    sandbox.stub(response, 'url').get(() => endpoint);
    sandbox.stub(global, 'fetch').callsFake(() => Promise.resolve(response));

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
      upload({}, { endpoint }).then(() => {
        throw new Error('Unexpected upload resolution during redirect.');
      }),
    ]);

    window.removeEventListener('hashchange', assertOnHashChange);
  });

  it('throws unhandled response', async () => {
    const endpoint = 'https://example.com';

    sandbox
      .stub(global, 'fetch')
      .resolves(new Response('', { status: 500, url: endpoint, statusText: 'Server error' }));

    try {
      await upload({}, { endpoint });
    } catch (error) {
      expect(error).to.be.instanceof(Error);
      expect(error.message).to.equal('Server error');
    }
  });
});
