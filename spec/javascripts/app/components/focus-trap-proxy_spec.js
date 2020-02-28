const proxyquire = require('proxyquire');
const sinon = require('sinon');

const stub = sinon.stub;

describe('focusTrap', () => {
  let proxy;
  let constructorCalled;
  const fakeFocusTrap = function() {
    const thisTrap = sinon.createStubInstance(function() {});
    thisTrap.deactivate = stub();
    thisTrap.activate = stub();
    constructorCalled = true;

    return thisTrap;
  }

  beforeEach(() => {
    constructorCalled = false;

    proxy = proxyquire('../../../../app/javascript/app/components/focus-trap-proxy', {
      // jump through this crazy hoop so we can spy on the method and ensure
      // the proxy object is calling the underlying `focusTrap` constructor
      'focus-trap': fakeFocusTrap
    }).default;
  });

  it('calls the underlying focusTrap object', () => {
    proxy('foo');
    expect(constructorCalled).to.be.true();
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
