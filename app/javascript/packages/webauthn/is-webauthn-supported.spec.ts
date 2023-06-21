import { useDefineProperty } from '@18f/identity-test-helpers';
import isWebauthnSupported from './is-webauthn-supported';

describe('isWebauthnSupported', () => {
  const defineProperty = useDefineProperty();

  context('browser does not support webauthn', () => {
    beforeEach(() => {
      defineProperty(navigator, 'credentials', {
        configurable: true,
        value: undefined,
      });
    });

    it('returns false', () => {
      expect(isWebauthnSupported()).to.equal(false);
    });
  });

  context('browser supports webauthn', () => {
    beforeEach(() => {
      defineProperty(navigator, 'credentials', {
        configurable: true,
        value: { get: () => {} },
      });
    });

    it('returns true', () => {
      expect(isWebauthnSupported()).to.equal(true);
    });
  });
});
