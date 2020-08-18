import { isLikelyMobile, hasMediaAccess, isCameraCapableMobile } from '@18f/identity-device';

describe('isLikelyMobile', () => {
  let originalUserAgent;
  beforeEach(() => {
    originalUserAgent = navigator.userAgent;
    Object.defineProperty(navigator, 'userAgent', {
      configurable: true,
      writable: true,
    });
  });

  afterEach(() => {
    navigator.userAgent = originalUserAgent;
  });

  it('returns false if not mobile', () => {
    navigator.userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36';

    expect(isLikelyMobile()).to.be.false();
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
    navigator.mediaDevices = originalMediaDevices;
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
    navigator.mediaDevices = originalMediaDevices;
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
