import { useDefineProperty } from '@18f/identity-test-helpers';
import isWebauthnPlatformSupported from './is-webauthn-platform-supported';

// Source (Adapted): https://www.chromium.org/updates/ua-reduction/#sample-ua-strings-final-reduced-state
const UNSUPPORTED_ANDROID_VERSION_UA =
  'Mozilla/5.0 (Linux; Android 8; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.1234.56 Mobile Safari/537.36';

// Source: https://www.chromium.org/updates/ua-reduction/#sample-ua-strings-final-reduced-state
const REDUCED_UNSUPPORTED_ANDROID_VERSION_UA =
  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.0.0 Mobile Safari/537.36';

// Source: https://www.chromium.org/updates/ua-reduction/#sample-ua-strings-final-reduced-state
const SUPPORTED_ANDROID_VERSION_UA =
  'Mozilla/5.0 (Linux; Android 9; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.1234.56 Mobile Safari/537.36';

// Source: https://chromium.googlesource.com/chromium/src/+/master/docs/ios/user_agent.md
const UNSUPPORTED_IOS_CHROME_VERSION_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) CriOS/56.0.2924.75 Mobile/14E5239e Safari/602.1';

// Source: https://chromium.googlesource.com/chromium/src/+/master/docs/ios/user_agent.md
const UNSUPPORTED_IOS_SAFARI_VERSION_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/603.1.23 (KHTML, like Gecko) Version/10.0 Mobile/14E5239e Safari/602.1';

// Source (Adapted): https://chromium.googlesource.com/chromium/src/+/master/docs/ios/user_agent.md
const SUPPORTED_IOS_CHROME_VERSION_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) CriOS/56.0.2924.75 Mobile/14E5239e Safari/602.1';

// Source (Adapted): https://chromium.googlesource.com/chromium/src/+/master/docs/ios/user_agent.md
const SUPPORTED_IOS_SAFARI_VERSION_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/603.1.23 (KHTML, like Gecko) Version/10.0 Mobile/14E5239e Safari/602.1';

// Source: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent#firefox_ua_string
const FIREFOX_UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X x.y; rv:42.0) Gecko/20100101 Firefox/42.0';

// Source: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent#chrome_ua_string
const DESKTOP_CHROME_UA =
  'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/51.0.2704.103 Safari/537.36';

// Source: Me
const DESKTOP_SAFARI_UA =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15';

const SUPPORTED_USER_AGENTS = [
  REDUCED_UNSUPPORTED_ANDROID_VERSION_UA,
  SUPPORTED_ANDROID_VERSION_UA,
  SUPPORTED_IOS_CHROME_VERSION_UA,
  SUPPORTED_IOS_SAFARI_VERSION_UA,
];

const UNSUPPORTED_USER_AGENTS = [
  UNSUPPORTED_ANDROID_VERSION_UA,
  UNSUPPORTED_IOS_CHROME_VERSION_UA,
  UNSUPPORTED_IOS_SAFARI_VERSION_UA,
  FIREFOX_UA,
  DESKTOP_CHROME_UA,
  DESKTOP_SAFARI_UA,
];

describe('isWebauthnPlatformSupported', () => {
  const defineProperty = useDefineProperty();

  describe('user agent support', () => {
    beforeEach(() => {
      defineProperty(window, 'PublicKeyCredential', {
        configurable: true,
        value: { isUserVerifyingPlatformAuthenticatorAvailable: () => Promise.resolve(true) },
      });
    });

    UNSUPPORTED_USER_AGENTS.forEach((userAgent) => {
      context(userAgent, () => {
        beforeEach(() => {
          defineProperty(navigator, 'userAgent', {
            configurable: true,
            value: userAgent,
          });
        });

        it('resolves to false', async () => {
          await expect(isWebauthnPlatformSupported()).to.eventually.equal(false);
        });
      });
    });

    SUPPORTED_USER_AGENTS.forEach((userAgent) => {
      context(userAgent, () => {
        beforeEach(() => {
          defineProperty(navigator, 'userAgent', {
            configurable: true,
            value: userAgent,
          });
        });

        it('resolves to true', async () => {
          await expect(isWebauthnPlatformSupported()).to.eventually.equal(true);
        });
      });
    });
  });

  context('supported user agent', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value: SUPPORTED_ANDROID_VERSION_UA,
      });
    });

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
});
