import {
  isLikelyMobile,
  hasMediaAccess,
  isCameraCapableMobile,
  isIPad,
} from '@18f/identity-device';
import { useDefineProperty } from '@18f/identity-test-helpers';

describe('isIPad', () => {
  const defineProperty = useDefineProperty();
  Object.defineProperty(navigator, 'userAgent', {
    configurable: true,
    writable: true,
  });
  Object.defineProperty(navigator, 'maxTouchPoints', {
    configurable: true,
    writable: true,
  });

  it('returns true if ipad is in the user agent string (old format)', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10',
    });

    expect(isIPad()).to.be.true();
  });

  it('returns false if the user agent is Macintosh but with 0 maxTouchPoints', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
    });

    expect(isIPad()).to.be.false();
  });

  it('returns true if the user agent is Macintosh but with 5 maxTouchPoints', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
    });
    defineProperty(navigator, 'maxTouchPoints', { value: 5 });

    expect(isIPad()).to.be.true();
  });

  it('returns false for non-Apple userAgent, even with 5 maxTouchPoints', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.5195.58 Mobile Safari/537.36',
    });
    defineProperty(navigator, 'maxTouchPoints', { value: 5 });

    expect(isIPad()).to.be.false();
  });
});

describe('isLikelyMobile', () => {
  const defineProperty = useDefineProperty();
  Object.defineProperty(navigator, 'userAgent', {
    configurable: true,
    writable: true,
  });
  Object.defineProperty(navigator, 'maxTouchPoints', {
    configurable: true,
    writable: true,
  });

  it('returns false if not mobile and has no touchpoints', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
    });
    defineProperty(navigator, 'maxTouchPoints', { value: 0 });

    expect(isLikelyMobile()).to.be.false();
  });

  it('returns true if there is an Apple user agent and 5 maxTouchPoints', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
    });
    defineProperty(navigator, 'maxTouchPoints', { value: 5 });

    expect(isLikelyMobile()).to.be.true();
  });

  it('returns true if likely mobile', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    });

    expect(isLikelyMobile()).to.be.true();
  });
});

describe('hasMediaAccess', () => {
  const defineProperty = useDefineProperty();
  beforeEach(() => {
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      writable: true,
    });
  });

  it('returns false if no media device API access', () => {
    defineProperty(navigator, 'mediaDevices', { value: undefined });

    expect(hasMediaAccess()).to.be.false();
  });

  it('returns true if media device API access', () => {
    navigator.mediaDevices = {};

    expect(hasMediaAccess()).to.be.true();
  });
});

describe('isCameraCapableMobile', () => {
  const defineProperty = useDefineProperty();
  beforeEach(() => {
    Object.defineProperty(navigator, 'userAgent', {
      configurable: true,
      writable: true,
    });
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      writable: true,
    });
  });

  it('returns false if not mobile', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
    });
    defineProperty(navigator, 'mediaDevices', { value: {} });

    expect(isCameraCapableMobile()).to.be.false();
  });

  it('returns false if no media device API access', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    });
    defineProperty(navigator, 'mediaDevices', { value: undefined });

    expect(isCameraCapableMobile()).to.be.false();
  });

  it('returns true if likely mobile and media device API access', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    });
    defineProperty(navigator, 'mediaDevices', {});

    expect(isCameraCapableMobile()).to.be.true();
  });
});
