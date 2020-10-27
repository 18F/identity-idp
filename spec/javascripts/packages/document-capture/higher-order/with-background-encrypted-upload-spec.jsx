import React, { useEffect } from 'react';
import sinon from 'sinon';
import { UploadContextProvider } from '@18f/identity-document-capture';
import withBackgroundEncryptedUpload, {
  blobToDataView,
  encrypt,
} from '@18f/identity-document-capture/higher-order/with-background-encrypted-upload';
import { useSandbox } from '../../../support/sinon';
import render from '../../../support/render';

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

describe('blobToDataView', () => {
  it('converts blob to data view', async () => {
    const data = new window.File(['Hello world'], 'demo.text', { type: 'text/plain' });
    const expected = new Uint8Array([72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100]).buffer;

    const dataView = await blobToDataView(data);
    expect(isArrayBufferEqual(dataView.buffer, expected)).to.be.true();
  });
});

describe('withBackgroundEncryptedUpload', () => {
  const sandbox = useSandbox();

  const Component = withBackgroundEncryptedUpload(({ onChange }) => {
    useEffect(() => {
      onChange({ foo: 'bar', baz: 'quux' });
    }, []);

    return null;
  });

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
      const expected = new Uint8Array([
        134,
        194,
        44,
        81,
        34,
        64,
        28,
        1,
        117,
        34,
        161,
        11,
        192,
        7,
        169,
        19,
        140,
        29,
        89,
        104,
        50,
        208,
        250,
        152,
        208,
        214,
        65,
      ]).buffer;

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
      const expected = new Uint8Array([
        134,
        194,
        44,
        81,
        34,
        64,
        28,
        1,
        117,
        34,
        161,
        11,
        192,
        7,
        169,
        19,
        140,
        29,
        89,
        104,
        50,
        208,
        250,
        152,
        208,
        214,
        65,
      ]).buffer;

      const encrypted = await encrypt(key, iv, data);
      expect(isArrayBufferEqual(encrypted, expected)).to.be.true();
    });
  });

  it('intercepts onChange to include background uploads', async () => {
    const onChange = sinon.spy();
    const key = await window.crypto.subtle.generateKey(
      {
        name: 'AES-GCM',
        length: 256,
      },
      true,
      ['encrypt', 'decrypt'],
    );
    sandbox.stub(window, 'fetch').callsFake(() => Promise.resolve({}));
    render(
      <UploadContextProvider
        backgroundUploadURLs={{ foo: 'about:blank' }}
        backgroundUploadEncryptKey={key}
      >
        <Component onChange={onChange} />)
      </UploadContextProvider>,
    );

    expect(onChange.calledOnce).to.be.true();
    const patch = onChange.getCall(0).args[0];
    expect(patch).to.have.keys(['foo', 'baz', 'foo_image_iv', 'foo_image_url']);
    expect(patch.foo).to.equal('bar');
    expect(patch.baz).to.equal('quux');
    expect(patch.foo_image_url).to.be.an.instanceOf(Promise);
    expect(await patch.foo_image_url).to.equal('about:blank');
    const [url, params] = window.fetch.getCall(0).args;
    expect(url).to.equal('about:blank');
    expect(params.method).to.equal('POST');
    expect(params.body).to.be.instanceOf(ArrayBuffer);
    const bodyAsString = String.fromCharCode.apply(null, new Uint8Array(params.body));
    expect(bodyAsString).to.not.equal('bar');
  });
});
