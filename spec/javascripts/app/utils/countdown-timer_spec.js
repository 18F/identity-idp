import sinon from 'sinon';
import countdownTimer from '../../../../app/javascript/app/utils/countdown-timer';

describe('countdownTimer', () => {
  it('does nothing if a HTMLElement is not supplied as the first argument', () => {
    expect(countdownTimer(false)).to.be.undefined();
  });

  describe('with clock', () => {
    let clock;
    let el;

    beforeEach(() => {
      clock = sinon.useFakeTimers();
      el = document.createElement('div');
    });

    afterEach(() => {
      clock.restore();
    });

    it('stays at 0s when time is exhausted', () => {
      countdownTimer(el);

      expect(el.innerHTML).to.equal('00:00');
      clock.tick(1000);
      expect(el.innerHTML).to.equal('00:00');
    });

    it('stays at 0s when time is exhausted for screen readers', () => {
      countdownTimer(el, 0, null, 1000, true);

      expect(el.innerHTML).to.equal('00:00:00');
      clock.tick(1000);
      expect(el.innerHTML).to.equal('00:00:00');
    });

    it('updates once per second', () => {
      countdownTimer(el, 10000);

      expect(el.innerHTML).to.equal('00:10');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:09');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:08');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:07');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:06');
    });

    it('updates once per second for screen readers', () => {
      countdownTimer(el, 10000, null, 1000, true);

      expect(el.innerHTML).to.equal('00:00:10');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:00:09');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:00:08');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:00:07');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('00:00:06');
    });
  });
});
