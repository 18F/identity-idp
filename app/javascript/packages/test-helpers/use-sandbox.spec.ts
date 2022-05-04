import useSandbox from './use-sandbox';

describe('useSandbox', () => {
  context('with fake timers', () => {
    const { clock } = useSandbox({ useFakeTimers: true });

    expect(clock.tick).to.be.a('function');

    it('supports invoking against a destructured clock', () => {
      clock.tick(0);
    });

    it('advances the clock', () => {
      const MAX_SAFE_32_BIT_INT = 2147483647;
      return new Promise((resolve) => {
        setTimeout(resolve, MAX_SAFE_32_BIT_INT);
        clock.tick(MAX_SAFE_32_BIT_INT);
      });
    });
  });
});
