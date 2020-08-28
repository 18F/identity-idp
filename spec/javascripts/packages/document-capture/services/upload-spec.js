import upload, {
  UploadFormEntriesError,
  toFormData,
} from '@18f/identity-document-capture/services/upload';
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
              errors: [
                { field_name: 'front', error_message: 'Please fill in this field' },
                { field_name: 'back', error_message: 'Please fill in this field' },
              ],
            }),
        }),
      ),
    );

    try {
      await upload({}, { endpoint: 'https://example.com', csrf: 'TYsqyyQ66Y' });
      throw new Error('This is a safeguard and should never be reached, since upload should error');
    } catch (error) {
      expect(error).to.be.instanceOf(UploadFormEntriesError);
      expect(error.rawErrors).to.deep.equal([
        { fieldName: 'front', errorMessage: 'Please fill in this field' },
        { fieldName: 'back', errorMessage: 'Please fill in this field' },
      ]);
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
      expect(error).to.be.instanceof(Error);
      expect(error.message).to.equal('Server error');
    }
  });
});
