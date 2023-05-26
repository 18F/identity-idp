import { rest } from 'msw';
import { setupServer } from 'msw/node';
import type { SetupServer } from 'msw/node';
import { SESSIONS_URL, requestSessionStatus, extendSession } from './requests';
import type { SessionLiveStatusResponse, SessionTimedOutStatusResponse } from './requests';

describe('requestSessionStatus', () => {
  let server: SetupServer;

  context('session inactive', () => {
    before(() => {
      server = setupServer(
        rest.get<{}, {}, SessionTimedOutStatusResponse>(SESSIONS_URL, (_req, res, ctx) =>
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
        rest.get<{}, {}, SessionLiveStatusResponse>(SESSIONS_URL, (_req, res, ctx) =>
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

  context('server responds with 401', () => {
    before(() => {
      server = setupServer(
        rest.get<{}, {}>(SESSIONS_URL, (_req, res, ctx) => res(ctx.status(401))),
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

  context('server responds with 500', () => {
    before(() => {
      server = setupServer(
        rest.get<{}, {}>(SESSIONS_URL, (_req, res, ctx) => res(ctx.status(500))),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('throws an error', async () => {
      await expect(requestSessionStatus()).to.be.rejected();
    });
  });
});

describe('extendSession', () => {
  let server: SetupServer;

  context('session active', () => {
    const timeout = new Date(Date.now() + 1000).toISOString();

    before(() => {
      server = setupServer(
        rest.put<{}, {}, SessionLiveStatusResponse>(SESSIONS_URL, (_req, res, ctx) =>
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

  context('server responds with 401', () => {
    before(() => {
      server = setupServer(
        rest.put<{}, {}>(SESSIONS_URL, (_req, res, ctx) => res(ctx.status(401))),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('resolves to the status', async () => {
      const result = await extendSession();

      expect(result).to.deep.equal({ isLive: false });
    });
  });

  context('server responds with 500', () => {
    before(() => {
      server = setupServer(
        rest.put<{}, {}>(SESSIONS_URL, (_req, res, ctx) => res(ctx.status(500))),
      );
      server.listen();
    });

    after(() => {
      server.close();
    });

    it('throws an error', async () => {
      await expect(extendSession()).to.be.rejected();
    });
  });
});
