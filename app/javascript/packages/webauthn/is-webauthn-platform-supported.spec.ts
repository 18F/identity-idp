import { useDefineProperty } from '@18f/identity-test-helpers';
import isWebauthnPlatformSupported from './is-webauthn-platform-supported';

describe('isWebauthnPlatformSupported', () => {
  const defineProperty = useDefineProperty();

  context('browser does not support webauthn', () => {
    beforeEach(() => {
      defineProperty(window, 'PublicKeyCredential', {
        configurable: true,
        value: undefined,
      });
    });

    it('resolves to false', async () => {
      await expect(isWebauthnPlatformSupported()).to.eventually.equal(false);
    });
  });

  context('browser supports webauthn', () => {
    context('device does not have platform authenticator available', () => {
      beforeEach(() => {
        defineProperty(window, 'PublicKeyCredential', {
          configurable: true,
          value: { isUserVerifyingPlatformAuthenticatorAvailable: () => Promise.resolve(false) },
        });
      });

      it('resolves to false', async () => {
        await expect(isWebauthnPlatformSupported()).to.eventually.equal(false);
      });
    });

    context('device has platform authenticator available', () => {
      beforeEach(() => {
        defineProperty(window, 'PublicKeyCredential', {
          configurable: true,
          value: { isUserVerifyingPlatformAuthenticatorAvailable: () => Promise.resolve(true) },
        });
      });

      it('resolves to true', async () => {
        await expect(isWebauthnPlatformSupported()).to.eventually.equal(true);
      });
    });
  });
});
