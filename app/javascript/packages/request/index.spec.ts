import { useSandbox } from '@18f/identity-test-helpers';
import { request } from '.';

describe('request', () => {
  const sandbox = useSandbox();

  it('includes the CSRF token by default', async () => {
    const csrf = 'TYsqyyQ66Y';
    const mockGetCSRF = () => csrf;

    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      const headers = init.headers as Headers;
      expect(headers.get('X-CSRF-Token')).to.equal(csrf);

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      csrf: mockGetCSRF,
    });

    expect(window.fetch).to.have.been.calledOnce();
  });
  it('works even if the CSRF token is not found on the page', async () => {
    sandbox.stub(window, 'fetch').callsFake(() =>
      Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      ),
    );

    await request('https://example.com', {
      csrf: () => undefined,
    });
  });
  it('does not try to send a csrf when csrf is false', async () => {
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      const headers = init.headers as Headers;
      expect(headers.get('X-CSRF-Token')).to.be.null();

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      csrf: false,
    });
  });
  it('prefers the json prop if both json and body props are provided', async () => {
    const preferredData = { prefered: 'data' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      json: preferredData,
      body: JSON.stringify({ bad: 'data' }),
    });
  });
  it('works with the native body prop', async () => {
    const preferredData = { this: 'works' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      body: JSON.stringify(preferredData),
    });
  });
  it('includes additional headers supplied in options', async () => {
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      const headers = init.headers as Headers;
      expect(headers.get('Some-Fancy')).to.equal('Header');

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      headers: {
        'Some-Fancy': 'Header',
      },
    });
  });
  it('skips json serialization when json is a boolean', async () => {
    const preferredData = { this: 'works' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      json: true,
      body: JSON.stringify(preferredData),
    });
  });
  it('converts a POJO to a JSON string with supplied via the json property', async () => {
    const preferredData = { this: 'works' };
    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(init.body).to.equal(JSON.stringify(preferredData));

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    await request('https://example.com', {
      json: preferredData,
    });
  });
});
