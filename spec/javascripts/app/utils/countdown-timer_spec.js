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

      expect(el.innerHTML).to.equal('0 minutes and 0 seconds');
      clock.tick(1000);
      expect(el.innerHTML).to.equal('0 minutes and 0 seconds');
    });

    it('updates once per second', () => {
      countdownTimer(el, 10000);

      expect(el.innerHTML).to.equal('0 minutes and 10 seconds');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('0 minutes and 9 seconds');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('0 minutes and 8 seconds');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('0 minutes and 7 seconds');
      clock.tick(1000);

      expect(el.innerHTML).to.equal('0 minutes and 6 seconds');
    });
  });
});
