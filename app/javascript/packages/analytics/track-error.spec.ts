import type { SinonStub } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import trackError from './track-error';

describe('trackError', () => {
  const sandbox = useSandbox();
  const endpoint = '/log';

  beforeEach(() => {
    sandbox.stub(global.navigator, 'sendBeacon').returns(true);
    document.body.innerHTML = `<script type="application/json" data-config>{"analyticsEndpoint":"${endpoint}"}</script>`;
  });

  it('tracks event', async () => {
    trackError(new Error('Oops!'));

    expect(global.navigator.sendBeacon).to.have.been.calledOnce();

    const [actualEndpoint, data] = (global.navigator.sendBeacon as SinonStub).firstCall.args;
    expect(actualEndpoint).to.eql(endpoint);

    const { event, payload } = JSON.parse(await data.text());
    const { name, message, stack, filename } = payload;

    expect(event).to.equal('Frontend Error');
    expect(name).to.equal('Error');
    expect(message).to.equal('Oops!');
    expect(stack).to.be.a('string');
    expect(filename).to.be.undefined();
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
