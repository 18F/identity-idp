import { useSandbox } from '@18f/identity-test-helpers';
import { render } from '@testing-library/react';
import { request } from '.';

describe('request', () => {
  const sandbox = useSandbox();

  // beforeEach(() => {
  //   sandbox.stub(window, 'fetch').resolves({
  //     json: () => Promise.resolve([{}]),
  //   } as Response);
  // });

  it('includes the CSRF token by default', async () => {
    const endpoint = 'https://example.com';
    const csrf = 'TYsqyyQ66Y';

    sandbox.stub(window, 'fetch').callsFake((url, init = {}) => {
      expect(url).to.equal(endpoint);

      const { headers = {} } = init;
      expect(headers['X-CSRF-Token']).to.equal(csrf);

      return Promise.resolve(
        new Response(new Blob([JSON.stringify({})]), {
          status: 200,
        }),
      );
    });

    render(
      <head>
        <meta name="csrf-token" content={csrf} />
      </head>,
    );

    await request('https://example.com');
  });
  // it('works even if the CSRF token is not found on the page', async () => {});
  // it('prefers the json prop if both json and body props are provided', async () => {});
  // it('works with the native body prop', async () => {});
  // it('includes additional headers supplied in options', async () => {});
  // it('skips json serialization when json is a boolean', async () => {});
  // it('converts a POJO to a JSON string with supplied via the json property', async () => {});
  // it('works when using neither extended json prop nor the csrf flag', async () => {});
});
