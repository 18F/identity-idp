import {
  isLikelyMobile,
  hasMediaAccess,
  isCameraCapableMobile,
  isIPad,
} from '@18f/identity-device';

import { useDefineProperty } from '@18f/identity-test-helpers';

Object.defineProperty(navigator, 'userAgent', {
  configurable: true,
  writable: true,
});
Object.defineProperty(navigator, 'maxTouchPoints', {
  writable: true,
  configurable: true,
});

Object.defineProperty(navigator, 'mediaDevices', {
  writable: true,
  configurable: true,
});

describe('isIPad', () => {
  const defineProperty = useDefineProperty();

  context('iPad is in the user agent string (old format)', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10',
      });
    });

    it('returns true', () => {
      expect(isIPad()).to.be.true();
    });
  });

  context('The user agent is Macintosh but with 0 maxTouchPoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
    });

    it('returns false', () => {
      expect(isIPad()).to.be.false();
    });
  });

  context('The user agent is Macintosh but with 5 maxTouchPoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
      defineProperty(navigator, 'maxTouchPoints', { value: 5 });
    });

    it('returns true', () => {
      expect(isIPad()).to.be.true();
    });
  });

  context('Non-Apple userAgent, even with 5 maxTouchPoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.5195.58 Mobile Safari/537.36',
      });
      defineProperty(navigator, 'maxTouchPoints', { value: 5 });
    });
    it('returns false', () => {
      expect(isIPad()).to.be.false();
    });
  });
});

describe('isLikelyMobile', () => {
  const defineProperty = useDefineProperty();

  context('Is not mobile and has no touchpoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
        writable: true,
        configurable: true,
      });
      defineProperty(navigator, 'maxTouchPoints', { value: 0 });
    });

    it('returns false', () => {
      expect(isLikelyMobile()).to.be.false();
    });
  });

  context('There is an Apple user agent and 5 maxTouchPoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
      defineProperty(navigator, 'maxTouchPoints', { value: 5 });
    });

    it('returns true', () => {
      expect(isLikelyMobile()).to.be.true();
    });
  });

  context('There is an explicit iPhone user agent', () => {
    defineProperty(navigator, 'userAgent', {
      value:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
    });

    it('returns true', () => {
      expect(isLikelyMobile()).to.be.true();
    });
  });
});

describe('hasMediaAccess', () => {
  Object.defineProperty(navigator, 'mediaDevices', {
    writable: true,
    configurable: true,
  });
  const defineProperty = useDefineProperty();

  context('No media device API access', () => {
    beforeEach(() => {
      defineProperty(navigator, 'mediaDevices', { value: undefined });
    });

    it('returns false', () => {
      expect(hasMediaAccess()).to.be.false();
    });
  });

  it('Has media device API access', () => {
    beforeEach(() => {
      defineProperty(navigator, 'mediaDevices', { value: {} });
    });

    it('returns true', () => {
      expect(hasMediaAccess()).to.be.true();
    });
  });
});

describe('isCameraCapableMobile', () => {
  const defineProperty = useDefineProperty();

  context('Is not mobile', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
      defineProperty(navigator, 'mediaDevices', { value: {} });
    });

    it('returns false', () => {
      expect(isCameraCapableMobile()).to.be.false();
    });
  });

  context('No media device API access', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      });
      defineProperty(navigator, 'mediaDevices', { value: undefined });
    });

    it('returns false', () => {
      expect(isCameraCapableMobile()).to.be.false();
    });
  });

  context('Is likely mobile and media device API access', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        value:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      });
      defineProperty(navigator, 'mediaDevices', {});
    });

    it('returns true', () => {
      expect(isCameraCapableMobile()).to.be.true();
    });
  });
});
