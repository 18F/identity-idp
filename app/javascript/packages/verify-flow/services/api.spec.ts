import type { SinonStub } from 'sinon';
import { useSandbox, useDefineProperty } from '@18f/identity-test-helpers';
import { post } from './api';

describe('post', () => {
  const sandbox = useSandbox();
  const defineProperty = useDefineProperty();

  beforeEach(() => {
    sandbox
      .stub(window, 'fetch')
      .resolves({ json: () => Promise.resolve({ received: true }) } as Response);

    defineProperty(window, 'location', {
      value: {
        href: 'https://example.com/foo/bar',
        pathname: '/foo/bar',
      },
    });
  });

  it('sends to API route associated with current path', () => {
    post({});

    const url: string = (window.fetch as SinonStub).getCall(0).args[0];

    expect(url).to.equal('https://example.com/api/foo/bar');
  });

  it('sends as JSON', () => {
    post({});

    const requestInit: RequestInit = (window.fetch as SinonStub).getCall(0).args[1];
    const headers = requestInit.headers as Headers;
    expect(headers.get('content-type')).to.equal('application/json');
  });

  it('sends CSRF', () => {
    const csrf = document.createElement('meta');
    csrf.name = 'csrf-token';
    csrf.content = 'csrf-value';
    document.body.appendChild(csrf);

    post({});

    const requestInit: RequestInit = (window.fetch as SinonStub).getCall(0).args[1];
    const headers = requestInit.headers as Headers;
    expect(headers.get('x-csrf-token')).to.equal('csrf-value');
  });

  it('resolves to parsed response JSON', async () => {
    const { received } = await post({});

    expect(received).to.equal(true);
  });
});
