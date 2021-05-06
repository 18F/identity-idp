import sinon from 'sinon';

/**
 * Returns an instance of a Sinon sandbox, and automatically restores all stubbed methods after each
 * test case.
 *
 * @param {sinon.SinonSandboxConfig=} config
 */
export function useSandbox(config) {
  const { useFakeTimers = false, ...remainingConfig } = config ?? {};
  const sandbox = sinon.createSandbox(remainingConfig);

  beforeEach(() => {
    // useFakeTimers overrides global timer functions as soon as sandbox is created, thus leaking
    // across tests. Instead, wait until tests start to initialize.
    if (useFakeTimers) {
      sandbox.useFakeTimers();
    }
  });

  afterEach(() => {
    sandbox.reset();
    sandbox.restore();

    if (useFakeTimers) {
      sandbox.clock.restore();
    }
  });

  return sandbox;
}

/**
 * Chai plugin which allows a combination of `calledWith` and `eventually` to expect an eventual
 * spy (stub) call.
 *
 * @param {import('chai')} chai Chai object.
 * @param {import('chai/lib/chai/utils')} utils Chai plugin utilities.
 */
export function sinonChaiAsPromised({ Assertion }, utils) {
  /* eslint-disable no-underscore-dangle */
  Assertion.overwriteProperty(
    'eventually',
    (originalGetter) =>
      function (...args) {
        const isSpy = typeof this._obj?.getCall === 'function';
        if (isSpy) {
          utils.flag(this, 'spyEventually', true);
        }

        return originalGetter.apply(this, ...args);
      },
  );

  Assertion.overwriteMethod(
    'calledWith',
    (originalMethod) =>
      function (action, ...otherArgs) {
        if (!utils.flag(this, 'spyEventually')) {
          return originalMethod.apply(this, [action, ...otherArgs]);
        }

        return new Promise((resolve) => {
          if (this._obj.calledWith(action)) {
            resolve();
          } else {
            this._obj.withArgs(action).callsFake(resolve);
          }
        });
      },
    (originalMethod) => originalMethod,
  );
  /* eslint-enable no-underscore-dangle */
}
