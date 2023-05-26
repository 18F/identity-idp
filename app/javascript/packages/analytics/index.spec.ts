import { trackEvent, trackError } from '@18f/identity-analytics';
import { usePropertyValue, useSandbox } from '@18f/identity-test-helpers';
import type { SinonStub } from 'sinon';

function blobTextContents(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.addEventListener('loadend', () => {
      resolve(reader.result as string);
    });
    reader.addEventListener('error', reject);
    reader.readAsText(blob, 'utf-8');
  });
}

describe('trackEvent', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(global, 'fetch').resolves();
    sandbox.stub(global.navigator, 'sendBeacon').returns(true);
  });

  context('page configuration does not exist', () => {
    it('does not call sendBeacon or fetch and resolves to undefined', () => {
      const result = trackEvent('name');

      expect(result).to.be.undefined();

      expect(global.navigator.sendBeacon).not.to.have.been.called();
      expect(global.fetch).not.to.have.been.called();
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

        expect(await blobTextContents(data)).to.eql('{"event":"name"}');
      });

      it('does not call fetch', () => {
        trackEvent('name');
        expect(global.fetch).not.to.have.been.called();
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
        expect(await blobTextContents(data)).to.eql('{"event":"name","payload":{"foo":"bar"}}');
      });
      it('does not fall back to fetch', () => {
        trackEvent('name', { foo: 'bar' });
        expect(global.fetch).not.to.have.been.called();
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

      it('does not call fetch', () => {
        trackEvent('name');
        expect(global.fetch).not.to.have.been.called();
      });
    });
  });
});

describe('trackError', () => {
  it('is a noop', () => {
    trackError(new Error('Oops!'));
  });

  context('with newrelic agent present', () => {
    const sandbox = useSandbox();
    const noticeError = sandbox.stub();
    usePropertyValue(globalThis as any, 'newrelic', { noticeError });

    it('notices error in newrelic', () => {
      const error = new Error('Oops!');
      trackError(error);

      expect(noticeError).to.have.been.calledWith(error);
    });
  });
});
