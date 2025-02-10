import {
  isLikelyMobile,
  hasMediaAccess,
  isCameraCapableMobile,
  isIPad,
} from '@18f/identity-device';
import { useDefineProperty } from '@18f/identity-test-helpers';

describe('isIPad', () => {
  const defineProperty = useDefineProperty();

  context('ipad is in the user agent string (old format)', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10',
      });
    });

    it('returns true', () => {
      expect(isIPad()).to.be.true();
    });
  });

  context('user agent is Macintosh', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
    });

    context('with 0 maxTouchPoints', () => {
      beforeEach(() => {
        defineProperty(navigator, 'maxTouchPoints', {
          configurable: true,
          value:
            'Mozilla/5.0(iPad; U; CPU iPhone OS 3_2 like Mac OS X; en-us) AppleWebKit/531.21.10 (KHTML, like Gecko) Version/4.0.4 Mobile/7B314 Safari/531.21.10',
        });
      });

      it('returns false', () => {
        expect(isIPad()).to.be.false();
      });
    });

    context('with 5 maxTouchPoints', () => {
      beforeEach(() => {
        defineProperty(navigator, 'maxTouchPoints', {
          configurable: true,
          value: 5,
        });
      });

      it('returns true', () => {
        expect(isIPad()).to.be.true();
      });
    });
  });

  context('with non-Apple userAgent and 5 maxTouchPoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/105.0.5195.58 Mobile Safari/537.36',
      });
      defineProperty(navigator, 'maxTouchPoints', {
        configurable: true,
        value: 5,
      });
    });

    it('returns false', () => {
      expect(isIPad()).to.be.false();
    });
  });
});

describe('isLikelyMobile', () => {
  const defineProperty = useDefineProperty();

  context('not mobile and has no touchpoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
      defineProperty(navigator, 'maxTouchPoints', {
        configurable: true,
        value: 0,
      });
    });

    it('returns false', () => {
      expect(isLikelyMobile()).to.be.false();
    });
  });

  context('Apple user agent and 5 maxTouchPoints', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
      defineProperty(navigator, 'maxTouchPoints', {
        configurable: true,
        value: 5,
      });
    });

    it('returns true', () => {
      expect(isLikelyMobile()).to.be.true();
    });
  });

  context('with likely-mobile user agent', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      });
    });

    it('returns true', () => {
      expect(isLikelyMobile()).to.be.true();
    });
  });
});

describe('hasMediaAccess', () => {
  const defineProperty = useDefineProperty();

  context('without media device API access', () => {
    beforeEach(() => {
      defineProperty(navigator, 'mediaDevices', {
        configurable: true,
        value: undefined,
      });
    });

    it('returns false', () => {
      expect(hasMediaAccess()).to.be.false();
    });
  });

  context('with media device API access', () => {
    beforeEach(() => {
      defineProperty(navigator, 'mediaDevices', {
        configurable: true,
        value: {},
      });
    });

    it('returns true', () => {
      expect(hasMediaAccess()).to.be.true();
    });
  });
});

describe('isCameraCapableMobile', () => {
  const defineProperty = useDefineProperty();

  context('not mobile', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/84.0.4147.125 Safari/537.36',
      });
    });

    it('returns false', () => {
      expect(isCameraCapableMobile()).to.be.false();
    });
  });

  context('likely mobile', () => {
    beforeEach(() => {
      defineProperty(navigator, 'userAgent', {
        configurable: true,
        value:
          'Mozilla/5.0 (iPhone; CPU iPhone OS 12_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
      });
    });

    context('without media device API access', () => {
      beforeEach(() => {
        defineProperty(navigator, 'mediaDevices', {
          configurable: true,
          value: undefined,
        });
      });

      it('returns false', () => {
        expect(isCameraCapableMobile()).to.be.false();
      });
    });

    context('with media device API access', () => {
      beforeEach(() => {
        defineProperty(navigator, 'mediaDevices', {
          configurable: true,
          value: {},
        });
      });

      it('returns true', () => {
        expect(isCameraCapableMobile()).to.be.true();
      });
    });
  });
});
