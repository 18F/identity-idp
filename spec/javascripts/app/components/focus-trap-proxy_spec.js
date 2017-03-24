const proxyquire = require('proxyquireify')(require);
const stub = sinon.stub;
const focusTrapStub = stub();

const focusTrapAPI = {
  activate: stub(),
  deactivate: stub(),
};

focusTrapStub.returns(focusTrapAPI);

describe('focusTrap', () => {
  let proxy;

  beforeEach(function() {
    proxy = proxyquire('app/components/focus-trap-proxy', {
      'focus-trap': focusTrapStub,
    }).focusTrapProxy;
  });

  it('calls the underlying focusTrap object', () => {
    proxy('', {});
    expect(focusTrapStub.calledOnce).to.be.true();
  });

  context('#activate', () => {
    it('deactivates all registered traps when activate is called', () => {
      const trapA = proxy('', {});

      // define a couple more traps
      proxy('', {});
      proxy('', {});

      trapA.activate();

      expect(focusTrapAPI.activate.calledOnce).to.be.true();
      expect(focusTrapAPI.deactivate.callCount).to.equal(3);
    });
  });

  context('#deactivate', () => {
    it('proxies to `deactivate` and reactivates the last active trap', () => {
      const trapA = proxy('', {});
      const trapB = proxy('', {});

      trapA.activate();
      trapB.activate();
      trapB.deactivate();

      expect(focusTrapAPI.activate.calledThrice).to.be.true();
      expect(focusTrapAPI.deactivate.callCount).to.equal(5);
    });
  });
});
