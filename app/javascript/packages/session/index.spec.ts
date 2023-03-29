import { rest } from 'msw';
import { setupServer } from 'msw/node';
import type { SetupServer } from 'msw/node';
import {
  STATUS_API_ENDPOINT,
  KEEP_ALIVE_API_ENDPOINT,
  requestSessionStatus,
  extendSession,
} from './index';
import type { SessionStatusResponse } from './index';

describe('requestSessionStatus', () => {
  let live: boolean;
  let timeout: string;

  let server: SetupServer;
  before(() => {
    server = setupServer(
      rest.get<{}, {}, SessionStatusResponse>(STATUS_API_ENDPOINT, (_req, res, ctx) =>
        res(ctx.json({ live, timeout })),
      ),
    );
    server.listen();
  });

  after(() => {
    server.close();
  });

  context('session inactive', () => {
    beforeEach(() => {
      live = false;
      timeout = new Date().toISOString();
    });

    it('resolves to the status', async () => {
      const result = await requestSessionStatus();

      expect(result).to.deep.equal({ live: false, timeout });
    });
  });

  context('session active', () => {
    beforeEach(() => {
      live = true;
      timeout = new Date(Date.now() + 1000).toISOString();
    });

    it('resolves to the status', async () => {
      const result = await requestSessionStatus();

      expect(result).to.deep.equal({ live: true, timeout });
    });
  });
});

describe('extendSession', () => {
  const timeout = new Date(Date.now() + 1000).toISOString();

  let server: SetupServer;
  before(() => {
    server = setupServer(
      rest.post<{}, {}, SessionStatusResponse>(KEEP_ALIVE_API_ENDPOINT, (_req, res, ctx) =>
        res(ctx.json({ live: true, timeout })),
      ),
    );
    server.listen();
  });

  after(() => {
    server.close();
  });

  it('resolves to the status', async () => {
    const result = await extendSession();

    expect(result).to.deep.equal({ live: true, timeout });
  });
});
