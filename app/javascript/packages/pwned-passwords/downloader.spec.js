import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import Downloader from './downloader.js';

describe('Downloader', () => {
  let server;
  before(() => {
    server = setupServer(
      http.get('https://api.pwnedpasswords.com/range/00000', () =>
        HttpResponse.text('foo:30\r\nbar:20'),
      ),
      http.get('https://api.pwnedpasswords.com/range/00001', () => HttpResponse.text('baz:10')),
      http.get('https://api.pwnedpasswords.com/range/00002', () => HttpResponse.text('quux:40')),
    );
    server.listen();
  });

  after(() => {
    server.resetHandlers();
    server.close();
  });

  describe('#download', () => {
    it('downloads data with specified options', async () => {
      const downloader = new Downloader({
        rangeStart: '00000',
        rangeEnd: '00002',
        concurrency: 1,
        maxSize: 3,
      });

      const results = Array.from(await downloader.download());

      expect(results).to.have.deep.members([
        { hash: '00000bar', prevalence: 20 },
        { hash: '00000foo', prevalence: 30 },
        { hash: '00002quux', prevalence: 40 },
      ]);
    });

    it('retries when download experiences an error', async () => {
      let didError = false;

      server.resetHandlers();
      server.use(
        http.get('https://api.pwnedpasswords.com/range/00000', () => {
          if (!didError) {
            didError = true;
            return HttpResponse.error();
          }

          return HttpResponse.text('foo:30\r\nbar:20');
        }),
      );

      const downloader = new Downloader({
        rangeStart: '00000',
        rangeEnd: '00000',
        maxRetry: 2,
      });

      const results = Array.from(await downloader.download());
      expect(didError).to.be.true();
      expect(results).to.have.deep.members([
        { hash: '00000bar', prevalence: 20 },
        { hash: '00000foo', prevalence: 30 },
      ]);
    });

    it('throws when requests repeatedly error after retry', async () => {
      let attempts = 0;
      server.resetHandlers();
      server.use(
        http.get('https://api.pwnedpasswords.com/range/00000', () => {
          attempts++;
          return HttpResponse.error();
        }),
      );

      const downloader = new Downloader({
        rangeStart: '00000',
        rangeEnd: '00000',
        maxRetry: 5,
      });

      try {
        await downloader.download();
        throw new Error('Expected downloader to throw.');
      } catch {}

      expect(attempts).to.equal(6);
    });
  });
});
