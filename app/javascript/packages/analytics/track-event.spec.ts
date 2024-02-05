import { trackEvent } from '@18f/identity-analytics';
import { useSandbox } from '@18f/identity-test-helpers';
import type { SinonStub } from 'sinon';

describe('trackEvent', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(global.navigator, 'sendBeacon').returns(true);
  });

  context('page configuration does not exist', () => {
    it('does not call sendBeacon and resolves to undefined', () => {
      const result = trackEvent('name');

      expect(result).to.be.undefined();

      expect(global.navigator.sendBeacon).not.to.have.been.called();
    });
  });

  context('page configuration exists', () => {
    const endpoint = '/log';

    beforeEach(() => {
      document.body.innerHTML = `<script type="application/json" data-config>{"analyticsEndpoint":"${endpoint}"}</script>`;
    });

    context('no payload', () => {
      it('calls sendBeacon and resolves to undefined', () => {
        const result = trackEvent('name');

        expect(result).to.be.undefined();

        expect(global.navigator.sendBeacon).to.have.been.calledOnce();

        const [actualEndpoint, data] = (global.navigator.sendBeacon as SinonStub).firstCall.args;
        expect(actualEndpoint).to.eql(endpoint);
        expect(data).to.eql('{"event":"name"}');
      });
    });

    context('payload', () => {
      it('calls sendBeacon and resolves to undefined', () => {
        const result = trackEvent('name', { foo: 'bar' });

        expect(result).to.be.undefined();

        expect(global.navigator.sendBeacon).to.have.been.calledOnce();

        const [actualEndpoint, data] = (global.navigator.sendBeacon as SinonStub).firstCall.args;

        expect(actualEndpoint).to.eql(endpoint);
        expect(data).to.eql('{"event":"name","payload":{"foo":"bar"}}');
      });
    });

    context('sendBeacon() throws', () => {
      beforeEach(() => {
        global.navigator.sendBeacon = sandbox.stub().throws();
      });

      it('throws', () => {
        expect(() => {
          trackEvent('name');
        }).to.throw();
      });
    });

    context('sendBeacon() returns false', () => {
      beforeEach(() => {
        global.navigator.sendBeacon = sandbox.stub().returns(false);
      });

      it('returns undefined', () => {
        const result = trackEvent('name');
        expect(result).to.be.undefined();
      });
    });
  });
});
