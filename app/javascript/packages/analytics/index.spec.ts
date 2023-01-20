import type { SinonStub } from 'sinon';
import { trackEvent, trackError } from '@18f/identity-analytics';
import { usePropertyValue, useSandbox } from '@18f/identity-test-helpers';

describe('trackEvent', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(global, 'fetch').resolves();
  });

  context('page configuration does not exist', () => {
    it('does not fetch and resolves to undefined', async () => {
      const result = await trackEvent('name');

      expect(result).to.be.undefined();
      expect(global.fetch).not.to.have.been.called();
    });
  });

  context('page configuration exists', () => {
    const endpoint = '/log';

    beforeEach(() => {
      document.body.innerHTML = `<script type="application/json" data-config>{"analyticsEndpoint":"${endpoint}"}</script>`;
    });

    context('no payload', () => {
      it('fetches and resolves to undefined', async () => {
        const result = await trackEvent('name');

        expect(result).to.be.undefined();
        expect(global.fetch).to.have.been.calledWith(
          endpoint,
          sandbox.match({
            body: '{"event":"name"}',
            headers: { 'Content-Type': 'application/json' },
            method: 'POST',
          }),
        );
      });
    });

    context('payload', () => {
      it('fetches and resolves to undefined', async () => {
        const result = await trackEvent('name', { foo: 'bar' });

        expect(result).to.be.undefined();
        expect(global.fetch).to.have.been.calledWith(
          endpoint,
          sandbox.match({
            body: '{"event":"name","payload":{"foo":"bar"}}',
            headers: { 'Content-Type': 'application/json' },
            method: 'POST',
          }),
        );
      });
    });

    context('a network error occurs in the request', () => {
      beforeEach(() => {
        (global.fetch as SinonStub).rejects(new TypeError());
      });

      it('absorbs the error', async () => {
        await trackEvent('name');
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
