import type { SinonStub } from 'sinon';
import { useSandbox } from '@18f/identity-test-helpers';
import { isErrorResponse, post } from './api';

describe('post', () => {
  const sandbox = useSandbox();

  beforeEach(() => {
    sandbox.stub(window, 'fetch');
  });

  it('sends to API route associated with current path', () => {
    post('/foo/bar', 'body');

    expect(window.fetch).to.have.been.calledWith(
      'http://example.test/foo/bar?locale=en',
      sandbox.match({ method: 'POST', body: 'body' }),
    );
  });

  it('resolves to plaintext', async () => {
    (window.fetch as SinonStub).resolves({
      text: () => Promise.resolve('response'),
    } as Response);

    const response = await post('/foo/bar', 'body');

    expect(response).to.equal('response');
  });

  context('with json option', () => {
    it('sends as JSON', () => {
      post('/foo/bar', { foo: 'bar' }, { json: true });

      expect(window.fetch).to.have.been.calledWith(
        'http://example.test/foo/bar?locale=en',
        sandbox.match({
          method: 'POST',
          body: '{"foo":"bar"}',
          headers: { 'Content-Type': 'application/json' },
        }),
      );
    });

    it('resolves to parsed response JSON', async () => {
      (window.fetch as SinonStub).resolves({
        json: () => Promise.resolve({ received: true }),
      } as Response);

      const { received } = await post('/foo/bar', { foo: 'bar' }, { json: true });

      expect(received).to.equal(true);
    });
  });

  context('with csrf option', () => {
    it('sends CSRF', () => {
      const csrf = document.createElement('meta');
      csrf.name = 'csrf-token';
      csrf.content = 'csrf-value';
      document.body.appendChild(csrf);

      post('/foo/bar', 'body', { csrf: true });

      expect(window.fetch).to.have.been.calledWith(
        'http://example.test/foo/bar?locale=en',
        sandbox.match({
          method: 'POST',
          body: 'body',
          headers: { 'X-CSRF-Token': 'csrf-value' },
        }),
      );
    });
  });
});

describe('isErrorResponse', () => {
  it('returns false if object is not an error response', () => {
    const response = {};
    const result = isErrorResponse(response);

    expect(result).to.be.false();
  });

  it('returns true if object is an error response', () => {
    const response = { errors: { field: ['message'] } };
    const result = isErrorResponse(response);

    expect(result).to.be.true();
  });
});
