import sinon from 'sinon';
import type { SinonSandboxConfig, SinonFakeTimers } from 'sinon';

/**
 * Returns an instance of a Sinon sandbox, and automatically restores all stubbed methods after each
 * test case.
 */
function useSandbox(config?: Partial<SinonSandboxConfig>) {
  const { useFakeTimers = false, ...remainingConfig } = config ?? {};
  const sandbox = sinon.createSandbox(remainingConfig);

  let tick = (_ms: number) => {};
  const clock = { tick: (ms: number) => tick(ms) } as unknown as SinonFakeTimers;

  beforeEach(() => {
    // useFakeTimers overrides global timer functions as soon as sandbox is created, thus leaking
    // across tests. Instead, wait until tests start to initialize.
    if (useFakeTimers) {
      Object.assign(clock, sandbox.useFakeTimers());
      tick = clock.tick;
    }
  });

  afterEach(() => {
    sandbox.reset();
    sandbox.restore();

    if (useFakeTimers) {
      sandbox.clock.restore();
    }
  });

  return { ...sandbox, clock };
}

export default useSandbox;
