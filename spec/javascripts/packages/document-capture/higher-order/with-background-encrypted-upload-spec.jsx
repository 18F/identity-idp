import { useEffect } from 'react';
import sinon from 'sinon';
import { UploadContextProvider, AnalyticsContext } from '@18f/identity-document-capture';
import withBackgroundEncryptedUpload, {
  BackgroundEncryptedUploadError,
  blobToArrayBuffer,
  encrypt,
} from '@18f/identity-document-capture/higher-order/with-background-encrypted-upload';
import { useSandbox } from '@18f/identity-test-helpers';
import * as analytics from '@18f/identity-analytics';
import { render } from '../../../support/document-capture';

/**
 * @param {ArrayBuffer} a
 * @param {ArrayBuffer} b
 *
 * @return {boolean}
 */
function isArrayBufferEqual(a, b) {
  if (a.byteLength !== b.byteLength) {
    return false;
  }

  const aView = new DataView(a);
  const bView = new DataView(b);
  for (let i = 0; i < a.byteLength; i++) {
    if (aView.getUint8(i) !== bView.getUint8(i)) {
      return false;
    }
  }

  return true;
}

describe('document-capture/higher-order/with-background-encrypted-upload', () => {
  const sandbox = useSandbox();

  describe('blobToArrayBuffer', () => {
    it('converts blob to data view', async () => {
      const data = new window.File(['Hello world'], 'demo.text', { type: 'text/plain' });
      const expected = new Uint8Array([72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]).buffer;

      const actual = await blobToArrayBuffer(data);
      expect(isArrayBufferEqual(actual, expected)).to.be.true();
    });

    it('rejects on filereader error', async () => {
      const error = new Error();
      sandbox.stub(window.FileReader.prototype, 'readAsArrayBuffer').callsFake(function () {
        Object.defineProperty(this, 'error', { value: error });
        this.onerror(new window.Event('error'));
      });

      try {
        await blobToArrayBuffer(
          new window.File(['Hello world'], 'demo.text', { type: 'text/plain' }),
        );
      } catch (actualError) {
        expect(actualError).to.equal(error);
      }
    });
  });

  describe('withBackgroundEncryptedUpload', () => {
    function OriginalComponent({ onChange, onError, errorOnMount }) {
      useEffect(() => {
        onChange({ foo: 'bar', baz: 'quux' });
      }, []);

      useEffect(() => {
        if (errorOnMount) {
          onError(new Error());
        }
      }, [errorOnMount]);

      return null;
    }
    const Component = withBackgroundEncryptedUpload(OriginalComponent);

    describe('encrypt', () => {
      it('resolves to AES-GCM encrypted data from string value', async () => {
        const key = await window.crypto.subtle.importKey(
          'raw',
          new Uint8Array(32).buffer,
          'AES-GCM',
          false,
          ['encrypt', 'decrypt'],
        );
        const iv = new Uint8Array(12);
        const data = 'Hello world';
        const expected = new Uint8Array(
          '134,194,44,81,34,64,28,1,117,34,161,11,192,7,169,19,140,29,89,104,50,208,250,152,208,214,65'.split(
            ',',
          ),
        ).buffer;

        const encrypted = await encrypt(key, iv, data);
        expect(isArrayBufferEqual(encrypted, expected)).to.be.true();
      });

      it('resolves to AES-GCM encrypted data from blob', async () => {
        const key = await window.crypto.subtle.importKey(
          'raw',
          new Uint8Array(32).buffer,
          'AES-GCM',
          false,
          ['encrypt', 'decrypt'],
        );
        const iv = new Uint8Array(12);
        const data = new window.File(['Hello world'], 'demo.text', { type: 'text/plain' });
        const expected = new Uint8Array(
          '134,194,44,81,34,64,28,1,117,34,161,11,192,7,169,19,140,29,89,104,50,208,250,152,208,214,65'.split(
            ',',
          ),
        ).buffer;

        const encrypted = await encrypt(key, iv, data);
        expect(isArrayBufferEqual(encrypted, expected)).to.be.true();
      });
    });

    it('passes through original onError', () => {
      const onError = sinon.spy();
      render(<Component onChange={() => {}} onError={onError} errorOnMount />);

      expect(onError).to.have.been.calledOnce();
    });

    it('maintains and decorates the original component display name', () => {
      expect(Component.displayName).to.equal('WithBackgroundEncryptedUpload(OriginalComponent)');
    });

    describe('upload', () => {
      async function renderWithResponse(response) {
        const trackEvent = sinon.spy();
        const onChange = sinon.spy();
        const onError = sinon.spy();
        const key = await window.crypto.subtle.generateKey(
          {
            name: 'AES-GCM',
            length: 256,
          },
          true,
          ['encrypt', 'decrypt'],
        );
        sandbox.stub(window, 'fetch').callsFake(() => Promise.resolve(response));
        render(
          <AnalyticsContext.Provider value={{ trackEvent }}>
            <UploadContextProvider
              backgroundUploadURLs={{ foo: 'about:blank' }}
              backgroundUploadEncryptKey={key}
            >
              <Component onChange={onChange} onError={onError} />
            </UploadContextProvider>
          </AnalyticsContext.Provider>,
        );

        return { onChange, onError, trackEvent };
      }

      context('success', () => {
        /** @type {Response} */
        const response = {
          ok: true,
          status: 200,
          headers: new window.Headers(),
        };

        it('intercepts onChange to include background uploads', async () => {
          const { onChange } = await renderWithResponse(response);

          expect(onChange.calledOnce).to.be.true();
          const patch = onChange.getCall(0).args[0];
          expect(patch).to.have.keys(['foo', 'baz', 'foo_image_iv', 'foo_image_url']);
          expect(patch.foo).to.equal('bar');
          expect(patch.baz).to.equal('quux');
          expect(patch.foo_image_url).to.be.an.instanceOf(Promise);
          expect(await patch.foo_image_url).to.equal('about:blank');
          const [url, params] = window.fetch.getCall(0).args;
          expect(url).to.equal('about:blank');
          expect(params.method).to.equal('PUT');
          expect(params.body).to.be.instanceOf(ArrayBuffer);
          const bodyAsString = String.fromCharCode.apply(null, new Uint8Array(params.body));
          expect(bodyAsString).to.not.equal('bar');
        });

        it('logs result', async () => {
          const { onChange, trackEvent } = await renderWithResponse(response);

          await onChange.getCall(0).args[0].foo_image_url;
          expect(trackEvent).to.have.been.calledTwice();
          expect(trackEvent).to.have.been.calledWith(
            'IdV: document capture async upload encryption',
            { success: true },
          );
          expect(trackEvent).to.have.been.calledWith(
            'IdV: document capture async upload submitted',
            { success: true, trace_id: null, status_code: 200 },
          );
        });
      });

      context('failure', () => {
        /** @type {Response} */
        const response = {
          ok: false,
          status: 403,
          headers: new window.Headers({
            'X-Amzn-Trace-Id': '1-67891233-abcdef012345678912345678',
          }),
          text: Promise.resolve(
            '<?xml version="1.0" encoding="UTF-8"?>\n' +
              '<Error>' +
              '<Code>InvalidAccessKeyId</Code>' +
              '<Message>The AWS Access Key Id you provided does not exist in our records.</Message>' +
              '<AWSAccessKeyId>...</AWSAccessKeyId>' +
              '<RequestId>...</RequestId>' +
              '<HostId>...</HostId>' +
              '</Error>',
          ),
        };

        it('throws on failed background upload', async () => {
          const { onChange } = await renderWithResponse(response);

          expect(onChange.calledOnce).to.be.true();
          const patch = onChange.getCall(0).args[0];
          expect(patch).to.have.keys(['foo', 'baz', 'foo_image_iv', 'foo_image_url']);
          expect(patch.foo).to.equal('bar');
          expect(patch.baz).to.equal('quux');
          expect(patch.foo_image_url).to.be.an.instanceOf(Promise);
          await patch.foo_image_url.catch((error) => {
            expect(error).to.be.instanceOf(BackgroundEncryptedUploadError);
          });
        });

        it('logs and throws on failed encryption', async () => {
          const error = new Error();
          sandbox.stub(window.crypto.subtle, 'encrypt').throws(error);
          sandbox.spy(analytics, 'trackError');
          const { onChange, onError, trackEvent } = await renderWithResponse(response);

          const patch = onChange.getCall(0).args[0];
          await patch.foo_image_url.catch(() => {});
          expect(onError).to.have.been.calledOnceWith(
            sinon.match.instanceOf(BackgroundEncryptedUploadError),
            { field: 'foo' },
          );
          expect(trackEvent).to.have.been.calledWith(
            'IdV: document capture async upload encryption',
            { success: false },
          );
          expect(analytics.trackError).to.have.been.calledWith(error);
          expect(window.fetch).not.to.have.been.called();
        });

        it('calls onError', async () => {
          const { onChange, onError } = await renderWithResponse(response);

          const patch = onChange.getCall(0).args[0];
          await patch.foo_image_url.catch(() => {});
          expect(onError).to.have.been.calledOnceWith(
            sinon.match.instanceOf(BackgroundEncryptedUploadError),
            { field: 'foo' },
          );
        });

        it('logs result', async () => {
          const { onChange, trackEvent } = await renderWithResponse(response);

          await onChange.getCall(0).args[0].foo_image_url.catch(() => {});
          expect(trackEvent).to.have.been.calledTwice();
          expect(trackEvent).to.have.been.calledWith(
            'IdV: document capture async upload encryption',
            { success: true },
          );
          expect(trackEvent).to.have.been.calledWith(
            'IdV: document capture async upload submitted',
            {
              success: false,
              trace_id: '1-67891233-abcdef012345678912345678',
              status_code: 403,
            },
          );
        });
      });
    });
  });
});
