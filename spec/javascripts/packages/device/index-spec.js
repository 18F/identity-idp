import {
  isLikelyMobile,
  hasMediaAccess,
  isCameraCapableMobile,
  isIPad,
} from '@18f/identity-device';

describe('isIPad', () => {
  let originalUserAgent;
  beforeEach(() => {
    originalUserAgent = navigator.userAgent;
    navigator.maxTouchPoints = 0;
    Object.defineProperty(navigator, 'userAgent', {
      configurable: true,
      writable: true,
    });
    Object.defineProperty(navigator, 'maxTouchPoints', {
      writable: true,
    });
  });

  afterEach(() => {
    navigator.userAgent = originalUserAgent;
  });

  it('returns true if ipad is in the user agent string (old format)', () => {
    navigator.userAgent =
      'Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10';

    expect(isIPad()).to.be.true();
  });

  it('returns false if the user agent is Macintosh but with 0 maxTouchPoints', () => {
    navigator.userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36';

    expect(isIPad()).to.be.false();
  });

  it('returns true if the user agent is Macintosh but with 5 maxTouchPoints', () => {
    navigator.userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36';
    navigator.maxTouchPoints = 5;

    expect(isIPad()).to.be.true();
  });

  it('returns false for non-Apple userAgent, even with 5 macTouchPoints', () => {
    navigator.userAgent =
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.5195.58 Mobile Safari/537.36';
    navigator.maxTouchPoints = 5;

    expect(isIPad()).to.be.false();
  });
});

describe('isLikelyMobile', () => {
  let originalUserAgent;
  beforeEach(() => {
    originalUserAgent = navigator.userAgent;
    navigator.maxTouchPoints = 0;
    Object.defineProperty(navigator, 'userAgent', {
      configurable: true,
      writable: true,
    });
    Object.defineProperty(navigator, 'maxTouchPoints', {
      writable: true,
    });
  });

  afterEach(() => {
    navigator.userAgent = originalUserAgent;
  });

  it('returns false if not mobile and has no touchpoints', () => {
    navigator.userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36';
    navigator.maxTouchPoints = 0;

    expect(isLikelyMobile()).to.be.false();
  });

  it('returns true if there is an Apple user agent and 5 maxTouchPoints', () => {
    navigator.userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36';
    navigator.maxTouchPoints = 5;

    expect(isLikelyMobile()).to.be.true();
  });

  it('returns true if likely mobile', () => {
    navigator.userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

    expect(isLikelyMobile()).to.be.true();
  });
});

describe('hasMediaAccess', () => {
  let originalMediaDevices;
  beforeEach(() => {
    originalMediaDevices = navigator.mediaDevices;
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      writable: true,
    });
  });

  afterEach(() => {
    if (originalMediaDevices === undefined) {
      delete navigator.mediaDevices;
    } else {
      navigator.mediaDevices = originalMediaDevices;
    }
  });

  it('returns false if no media device API access', () => {
    delete navigator.mediaDevices;

    expect(hasMediaAccess()).to.be.false();
  });

  it('returns true if media device API access', () => {
    navigator.mediaDevices = {};

    expect(hasMediaAccess()).to.be.true();
  });
});

describe('isCameraCapableMobile', () => {
  let originalUserAgent;
  let originalMediaDevices;
  beforeEach(() => {
    originalUserAgent = navigator.userAgent;
    originalMediaDevices = navigator.mediaDevices;
    Object.defineProperty(navigator, 'userAgent', {
      configurable: true,
      writable: true,
    });
    Object.defineProperty(navigator, 'mediaDevices', {
      configurable: true,
      writable: true,
    });
  });

  afterEach(() => {
    navigator.userAgent = originalUserAgent;
    if (originalMediaDevices === undefined) {
      delete navigator.mediaDevices;
    } else {
      navigator.mediaDevices = originalMediaDevices;
    }
  });

  it('returns false if not mobile', () => {
    navigator.userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36';
    navigator.mediaDevices = {};

    expect(isCameraCapableMobile()).to.be.false();
  });

  it('returns false if no media device API access', () => {
    navigator.userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
    delete navigator.mediaDevices;

    expect(isCameraCapableMobile()).to.be.false();
  });

  it('returns true if likely mobile and media device API access', () => {
    navigator.userAgent =
      'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';
    navigator.mediaDevices = {};

    expect(isCameraCapableMobile()).to.be.true();
  });
});
