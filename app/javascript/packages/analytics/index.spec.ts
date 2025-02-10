import { trackEvent, trackError } from '@18f/identity-analytics';
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
      it('calls sendBeacon and resolves to undefined', async () => {
        const result = trackEvent('name');

        expect(result).to.be.undefined();

        expect(global.navigator.sendBeacon).to.have.been.calledOnce();

        const [actualEndpoint, data] = (global.navigator.sendBeacon as SinonStub).firstCall.args;
        expect(actualEndpoint).to.eql(endpoint);
        expect(data).to.have.property('type').eql('application/json');

        expect(await data.text()).to.eql('{"event":"name"}');
      });
    });

    context('payload', () => {
      it('calls sendBeacon and resolves to undefined', async () => {
        const result = trackEvent('name', { foo: 'bar' });

        expect(result).to.be.undefined();

        expect(global.navigator.sendBeacon).to.have.been.calledOnce();

        const [actualEndpoint, data] = (global.navigator.sendBeacon as SinonStub).firstCall.args;

        expect(actualEndpoint).to.eql(endpoint);
        expect(data).to.have.property('type').eql('application/json');
        expect(await data.text()).to.eql('{"event":"name","payload":{"foo":"bar"}}');
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

describe('trackError', () => {
  const sandbox = useSandbox();
  const endpoint = '/log';

  beforeEach(() => {
    sandbox.stub(global.navigator, 'sendBeacon').returns(true);
    document.body.innerHTML = `<script type="application/json" data-config>{"analyticsEndpoint":"${endpoint}"}</script>`;
  });

  it('tracks event', async () => {
    trackError(new Error('Oops!'), { errorId: 'exampleId' });

    expect(global.navigator.sendBeacon).to.have.been.calledOnce();

    const [actualEndpoint, data] = (global.navigator.sendBeacon as SinonStub).firstCall.args;
    expect(actualEndpoint).to.eql(endpoint);

    const { event, payload } = JSON.parse(await data.text());
    const { name, message, stack, error_id: errorId } = payload;

    expect(event).to.equal('Frontend Error');
    expect(name).to.equal('Error');
    expect(message).to.equal('Oops!');
    expect(stack).to.be.a('string');
    expect(errorId).to.equal('exampleId');
  });

  context('with event parameter', () => {
    it('tracks event', async () => {
      const error = new Error('Oops!');
      const errorEvent = new ErrorEvent('error', { error, filename: 'file.js' });
      trackError(error, errorEvent);

      expect(global.navigator.sendBeacon).to.have.been.calledOnce();

      const [actualEndpoint, data] = (global.navigator.sendBeacon as SinonStub).firstCall.args;
      expect(actualEndpoint).to.eql(endpoint);

      const { event, payload } = JSON.parse(await data.text());
      const { name, message, stack, filename } = payload;

      expect(event).to.equal('Frontend Error');
      expect(name).to.equal('Error');
      expect(message).to.equal('Oops!');
      expect(stack).to.be.a('string');
      expect(filename).to.equal('file.js');
    });
  });
});
