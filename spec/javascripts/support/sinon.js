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
        } else {
          return originalGetter.apply(this, ...args);
        }
      },
  );

  const ifEventually = (callback) => (originalMethod) =>
    function (...args) {
      return (utils.flag(this, 'spyEventually') ? callback : originalMethod).apply(this, args);
    };

  Assertion.overwriteProperty(
    'called',
    ifEventually(function () {
      return new Promise((resolve) => {
        if (this._obj.called) {
          resolve();
        } else {
          this._obj.callsFake(resolve);
        }
      });
    }),
  );

  Assertion.overwriteMethod(
    'calledWith',
    ifEventually(function (...args) {
      return new Promise((resolve) => {
        if (this._obj.calledWith(...args)) {
          resolve();
        } else {
          this._obj.withArgs(...args).callsFake(resolve);
        }
      });
    }),
  );
  /* eslint-enable no-underscore-dangle */
}
