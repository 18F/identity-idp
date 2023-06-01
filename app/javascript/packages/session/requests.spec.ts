import { rest } from 'msw';
import { setupServer } from 'msw/node';
import type { SetupServer } from 'msw/node';
import {
  STATUS_API_ENDPOINT,
  KEEP_ALIVE_API_ENDPOINT,
  requestSessionStatus,
  extendSession,
} from './requests';
import type { SessionLiveStatusResponse, SessionTimedOutStatusResponse } from './requests';

describe('requestSessionStatus', () => {
  let server: SetupServer;

  context('session inactive', () => {
    before(() => {
      server = setupServer(
        rest.get<{}, {}, SessionTimedOutStatusResponse>(STATUS_API_ENDPOINT, (_req, res, ctx) =>
          res(ctx.json({ live: false, timeout: null })),
        ),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('resolves to the status', async () => {
      const result = await requestSessionStatus();

      expect(result).to.deep.equal({ isLive: false });
    });
  });

  context('session active', () => {
    let timeout: string;

    before(() => {
      timeout = new Date(Date.now() + 1000).toISOString();
      server = setupServer(
        rest.get<{}, {}, SessionLiveStatusResponse>(STATUS_API_ENDPOINT, (_req, res, ctx) =>
          res(ctx.json({ live: true, timeout })),
        ),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('resolves to the status', async () => {
      const result = await requestSessionStatus();

      expect(result).to.deep.equal({ isLive: true, timeout: new Date(timeout) });
    });
  });
});

describe('extendSession', () => {
  const timeout = new Date(Date.now() + 1000).toISOString();

  let server: SetupServer;
  before(() => {
    server = setupServer(
      rest.post<{}, {}, SessionLiveStatusResponse>(KEEP_ALIVE_API_ENDPOINT, (_req, res, ctx) =>
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

    expect(result).to.deep.equal({ isLive: true, timeout: new Date(timeout) });
  });
});
