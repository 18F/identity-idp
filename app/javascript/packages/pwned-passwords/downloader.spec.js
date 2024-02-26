import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import Downloader from './downloader.js';

describe('Downloader', () => {
  let server;
  before(() => {
    server = setupServer(
      http.get('https://api.pwnedpasswords.com/range/00000', () =>
        HttpResponse.text(
          '0005AD76BD555C1D6D771DE417A4B87E4B4:10\r\n000A8DAE4228F821FB418F59826079BF368:4',
        ),
      ),
      http.get('https://api.pwnedpasswords.com/range/00001', () =>
        HttpResponse.text('0005DE2A9668A41F6A508AFB6A6FC4A5610:1'),
      ),
      http.get('https://api.pwnedpasswords.com/range/00002', () =>
        HttpResponse.text('00652C89EA578B262D2D091136353D253BC:11'),
      ),
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
        { hash: '00000000A8DAE4228F821FB418F59826079BF368', prevalence: 4 },
        { hash: '000000005AD76BD555C1D6D771DE417A4B87E4B4', prevalence: 10 },
        { hash: '0000200652C89EA578B262D2D091136353D253BC', prevalence: 11 },
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

          return HttpResponse.text(
            '0005AD76BD555C1D6D771DE417A4B87E4B4:10\r\n000A8DAE4228F821FB418F59826079BF368:4',
          );
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
        { hash: '00000000A8DAE4228F821FB418F59826079BF368', prevalence: 4 },
        { hash: '000000005AD76BD555C1D6D771DE417A4B87E4B4', prevalence: 10 },
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
