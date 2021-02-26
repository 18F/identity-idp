import sinon from 'sinon';

/**
 * Test lifecycle hook which ensures that any call to `crypto.subtle.encrypt` using the AES-GCM
 * algorithm should always include an explicit `tagLength`, despite specification allowing for its
 * omission, due to browser-specific incompatibilities.
 *
 * This may be removed in the future if the upstream polyfill handles this incompatibility.
 *
 * @see https://github.com/vibornoff/webcrypto-shim/pull/44
 */
export function useBrowserCompatibleEncrypt() {
  let originalEncrypt;

  beforeEach(() => {
    originalEncrypt = window.crypto.subtle.encrypt;
    const stub = sinon.stub().callsFake(originalEncrypt);
    stub
      .withArgs(
        sinon.match({
          name: 'AES-GCM',
          tagLength: undefined,
        }),
      )
      .throws(new TypeError('Always pass numeric `tagLength`, even if default of `128`.'));

    window.crypto.subtle.encrypt = stub;
  });

  afterEach(() => {
    window.crypto.subtle.encrypt = originalEncrypt;
  });
}
