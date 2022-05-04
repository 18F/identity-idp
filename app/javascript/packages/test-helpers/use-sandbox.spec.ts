import useSandbox from './use-sandbox';

describe('useSandbox', () => {
  context('with fake timers', () => {
    const { clock } = useSandbox({ useFakeTimers: true });

    it('supports invoking against a destructured clock', () => {
      clock.tick(0);
    });
  });
});
