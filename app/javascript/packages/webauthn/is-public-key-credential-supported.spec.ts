import { useDefineProperty } from '@18f/identity-test-helpers';
import isPublicKeyCredentialSupported from './is-public-key-credential-supported';

describe('isPublicKeyCredentialSupported', () => {
  const defineProperty = useDefineProperty();

  context('public key credential exists', () => {
    beforeEach(() => {
      defineProperty(window, 'PublicKeyCredential', {
        configurable: true,
        value: { isUserVerifyingPlatformAuthenticatorAvailable: () => Promise.resolve(true) },
      });
    });

    it('resolves to true', () => {
      expect(isPublicKeyCredentialSupported()).to.equal(true);
    });

    context('isUserVerifyingPlatformAuthenticatorAvailable is set to false', () => {
      beforeEach(() => {
        defineProperty(window, 'PublicKeyCredential', {
          configurable: true,
          value: { isUserVerifyingPlatformAuthenticatorAvailable: () => Promise.resolve(false) },
        });
      });

      it('resolves to false', () => {
        expect(isPublicKeyCredentialSupported()).to.equal(false);
      });
    });
  });

  context('public key credential does not exist ', () => {
    beforeEach(() => {
      defineProperty(window, 'PublicKeyCredential', {
        configurable: true,
        value: undefined,
      });
    });

    it('resolves to false', () => {
      expect(isPublicKeyCredentialSupported()).to.equal(false);
    });
  });
});
