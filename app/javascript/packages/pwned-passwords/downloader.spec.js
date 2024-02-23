import { Readable } from 'node:stream';
import { ReadableStream } from 'stream/web';
import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import Downloader, { readLines } from './downloader.js';

describe('readLines', () => {
  it('yields lines as they are received from the stream', async () => {
    const encoder = new TextEncoder();
    const stream = new ReadableStream({
      start(controller) {
        controller.enqueue(encoder.encode('ba'));
        controller.enqueue(encoder.encode('z:10\r\n'));
        controller.enqueue(encoder.encode('quux:40\r'));
        controller.enqueue(encoder.encode('\nfoo:5'));
        controller.close();
      },
    });

    const expectedLines = ['baz:10', 'quux:40', 'foo:5'];
    for await (const line of readLines(Readable.fromWeb(stream))) {
      expect(line).to.equal(expectedLines.shift());
    }
  });
});

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

      expect(results).to.have.deep.members(['00000bar', '00000foo', '00002quux']);
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
      });

      const results = Array.from(await downloader.download());
      expect(didError).to.be.true();
      expect(results).to.have.deep.members(['00000bar', '00000foo']);
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
      });

      try {
        await downloader.download();
        throw new Error('Expected downloader to throw.');
      } catch {}

      expect(attempts).to.be.greaterThan(1);
    });
  });
});
