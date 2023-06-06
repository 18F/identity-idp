import sinon from 'sinon';
import type { SinonSandboxConfig, SinonFakeTimers } from 'sinon';

/**
 * Returns an instance of a Sinon sandbox, and automatically restores all stubbed methods after each
 * test case.
 */
function useSandbox(config?: Partial<SinonSandboxConfig>) {
  const { useFakeTimers = false, ...remainingConfig } = config ?? {};
  const sandbox = sinon.createSandbox(remainingConfig);

  // To support destructuring the result of the sandbox while still waiting for `beforeEach` to
  // initialize the fake timers, create a proxy to pass through to the underlying implementation.
  const clockImpl = {};
  if (useFakeTimers) {
    sandbox.clock = Object.fromEntries(
      Object.entries(sinon.useFakeTimers()).map(([key, value]) => [
        key,
        key === 'restore' ? value : (...args: any[]) => clockImpl[key](...args),
      ]),
    ) as SinonFakeTimers;
    sandbox.clock.restore();
  }

  // useFakeTimers overrides global.setTimeout, etc. (callable as setTimeout()), but does not
  // override window.setTimeout. So we'll do that.
  const originalWindowMethods = (
    [
      'clearImmediate',
      'clearInterval',
      'clearTimeout',
      'setImmediate',
      'setInterval',
      'setTimeout',
    ] as const
  ).reduce((methods, method) => {
    methods[method] = window[method];
    return methods;
  }, {});

  beforeEach(() => {
    // useFakeTimers overrides global timer functions as soon as sandbox is created, thus leaking
    // across tests. Instead, wait until tests start to initialize.
    if (useFakeTimers) {
      Object.assign(clockImpl, sandbox.useFakeTimers());
    }

    Object.keys(originalWindowMethods).forEach((method) => {
      window[method] = global[method];
    });
  });

  afterEach(() => {
    sandbox.reset();
    sandbox.restore();

    if (useFakeTimers) {
      sandbox.clock.restore();

      Object.keys(originalWindowMethods).forEach((method) => {
        window[method] = originalWindowMethods[method];
      });
    }
  });

  return sandbox;
}

export default useSandbox;
