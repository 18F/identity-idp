import { http, HttpResponse } from 'msw';
import { setupServer } from 'msw/node';
import type { SetupServer } from 'msw/node';
import { SESSIONS_URL, requestSessionStatus, extendSession } from './requests';
import type { SessionLiveStatusResponse, SessionTimedOutStatusResponse } from './requests';

describe('requestSessionStatus', () => {
  let server: SetupServer;

  context('session inactive', () => {
    before(() => {
      server = setupServer(
        http.get<{}, {}, SessionTimedOutStatusResponse>(SESSIONS_URL, () =>
          HttpResponse.json({ live: false, timeout: null }),
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
        http.get<{}, {}, SessionLiveStatusResponse>(SESSIONS_URL, () =>
          HttpResponse.json({ live: true, timeout }),
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
        http.get<{}, {}>(SESSIONS_URL, () => new HttpResponse(null, { status: 401 })),
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
        http.get<{}, {}>(SESSIONS_URL, () => new HttpResponse(null, { status: 500 })),
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
        http.put<{}, {}, SessionLiveStatusResponse>(SESSIONS_URL, () =>
          HttpResponse.json({ live: true, timeout }),
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
        http.put<{}, {}>(SESSIONS_URL, () => new HttpResponse(null, { status: 401 })),
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
        http.put<{}, {}>(SESSIONS_URL, () => new HttpResponse(null, { status: 500 })),
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
