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
