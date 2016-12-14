const proxyquire = require('proxyquireify')(require);

const spy = sinon.spy();
const countdownTimer = proxyquire('app/utils/countdown-timer.js', {
  './ms-formatter': spy,
  '@noCallThru': true,
}).default;

const fakeEl = {
  innerHTML: '',
};

describe('#countdownTimer', () => {
  it('does nothing if a HTMLElement is not supplied as the first argument', () => {
    expect(countdownTimer(false)).to.be.undefined();
    expect(spy.called).to.be.false();
  });

  describe('with clock', () => {
    let clock;

    beforeEach(() => {
      clock = sinon.useFakeTimers();
    });

    afterEach(() => {
      clock.restore();
      spy.reset();
    });

    it('with the default interval runs exactly once when given an HTMLElement', () => {
      countdownTimer(fakeEl);
      clock.tick(1000);
      expect(spy.calledOnce).to.be.true();
    });

    it('calls the msFormatter function once per second', () => {
      countdownTimer(fakeEl, 10000);
      clock.tick(4000);

      expect(spy.callCount).to.equal(5);
    });
  });
});
