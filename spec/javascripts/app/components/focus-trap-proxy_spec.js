const proxyquire = require('proxyquire');
const sinon = require('sinon');

const { stub } = sinon;

describe('focusTrap', () => {
  let proxy;

  beforeEach(() => {
    proxy = proxyquire('../../../../app/javascript/app/components/focus-trap-proxy', {
      // Mock external focus-trap library
      'focus-trap': () => ({
        deactivate: stub(),
        activate: stub(),
      }),
    }).default;
  });

  context('#deactivate', () => {
    it('proxies to `deactivate` and reactivates the last active trap', () => {
      const trapA = proxy('foo1');
      const trapB = proxy('foo2');

      const aFocusTrap = trapA.activate();
      const bFocusTrap = trapB.activate();

      bFocusTrap.deactivate.returns(bFocusTrap);

      trapB.deactivate();

      expect(aFocusTrap.activate.callCount).to.be.equal(2);
      expect(aFocusTrap.deactivate.callCount).to.be.equal(2);
      expect(bFocusTrap.activate.callCount).to.be.equal(1);
      expect(bFocusTrap.deactivate.callCount).to.equal(3);
    });
  });
});
