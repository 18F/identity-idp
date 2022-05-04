import { trackEvent } from '@18f/identity-analytics';
import { useSandbox } from '@18f/identity-test-helpers';

describe('trackEvent', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(window, 'fetch');
  });

  context('page configuration does not exist', () => {
    it('does not fetch and resolves to undefined', async () => {
      const result = await trackEvent('name');

      expect(result).to.be.undefined();
      expect(window.fetch).not.to.have.been.called();
    });
  });

  context('page configuration exists', () => {
    const endpoint = '/log';

    beforeEach(() => {
      document.body.innerHTML = `<script data-analytics-endpoint="${endpoint}"></script>`;
    });

    context('no payload', () => {
      it('fetches and resolves to undefined', async () => {
        const result = await trackEvent('name');

        expect(result).to.be.undefined();
        expect(window.fetch).to.have.been.calledWith(
          endpoint,
          sandbox.match({
            body: '{"event":"name","payload":{}}',
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
        expect(window.fetch).to.have.been.calledWith(
          endpoint,
          sandbox.match({
            body: '{"event":"name","payload":{"foo":"bar"}}',
            headers: { 'Content-Type': 'application/json' },
            method: 'POST',
          }),
        );
      });
    });
  });
});
