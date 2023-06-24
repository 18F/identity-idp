import { useDefineProperty } from '@18f/identity-test-helpers';
import isWebauthnPasskeySupported from './is-webauthn-passkey-supported';

// Source (Adapted): https://www.chromium.org/updates/ua-reduction/#sample-ua-strings-final-reduced-state
const UNSUPPORTED_ANDROID_VERSION_UA =
  'Mozilla/5.0 (Linux; Android 8; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.1234.56 Mobile Safari/537.36';

// Source: https://www.chromium.org/updates/ua-reduction/#sample-ua-strings-final-reduced-state
const REDUCED_UNSUPPORTED_ANDROID_VERSION_UA =
  'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.0.0 Mobile Safari/537.36';

// Source: https://www.chromium.org/updates/ua-reduction/#sample-ua-strings-final-reduced-state
const SUPPORTED_ANDROID_VERSION_CHROME_UA =
  'Mozilla/5.0 (Linux; Android 9; SM-A205U) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/93.0.1234.56 Mobile Safari/537.36';

// Source: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent/Firefox#mobile_and_tablet_indicators
const SUPPORTED_ANDROID_VERSION_FIREFOX_UA =
  'Mozilla/5.0 (Android 9; Mobile; rv:41.0) Gecko/41.0 Firefox/41.0';

// Source: https://chromium.googlesource.com/chromium/src/+/master/docs/ios/user_agent.md
const UNSUPPORTED_IOS_VERSION_CHROME_UA =
  'Mozilla/5.0 (iPhone; CPU iPhone OS 10_3 like Mac OS X) AppleWebKit/602.1.50 (KHTML, like Gecko) CriOS/56.0.2924.75 Mobile/14E5239e Safari/602.1';

// Source: https://chromium.googlesource.com/chromium/src/+/master/docs/ios/user_agent.md
const UNSUPPORTED_IOS_VERSION_SAFARI_UA =
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
  SUPPORTED_ANDROID_VERSION_CHROME_UA,
  SUPPORTED_IOS_CHROME_VERSION_UA,
  SUPPORTED_IOS_SAFARI_VERSION_UA,
];

const UNSUPPORTED_USER_AGENTS = [
  UNSUPPORTED_ANDROID_VERSION_UA,
  SUPPORTED_ANDROID_VERSION_FIREFOX_UA,
  UNSUPPORTED_IOS_VERSION_CHROME_UA,
  UNSUPPORTED_IOS_VERSION_SAFARI_UA,
  FIREFOX_UA,
  DESKTOP_CHROME_UA,
  DESKTOP_SAFARI_UA,
];

describe('isWebauthnPasskeySupported', () => {
  const defineProperty = useDefineProperty();

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

      it('resolves to false', () => {
        expect(isWebauthnPasskeySupported()).to.equal(false);
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

      it('resolves to true', () => {
        expect(isWebauthnPasskeySupported()).to.equal(true);
      });
    });
  });
});
