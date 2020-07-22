import sinon from 'sinon';

/**
 * Test lifecycle hook which creates a fake clock to use in tests where code
 * under test makes use of timers. Returns a function which evalutes to the
 * instance of the clock for that scope.
 *
 * @return {()=>import('sinon').SinonFakeTimers}
 */
export function useFakeTimers() {
  let clock;

  beforeEach(() => {
    clock = sinon.useFakeTimers();
  });

  afterEach(() => {
    clock.runAll();
    clock.restore();
  });

  return () => clock;
}
