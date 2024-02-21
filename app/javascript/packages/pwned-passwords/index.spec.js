import { setupServer } from 'msw/node';
import { http, HttpResponse } from 'msw';
import { Downloader } from './index.js';

const encoder = new TextEncoder();

describe('Downloader', () => {
  function createStreamResponder(chunks) {
    return () => {
      const stream = new ReadableStream({
        start(controller) {
          chunks.forEach((chunk) => controller.enqueue(encoder.encode(chunk)));
          controller.close();
        },
      });

      return new HttpResponse(stream, {
        headers: {
          'Content-Type': 'text/plain',
        },
      });
    };
  }

  let server;
  before(() => {
    server = setupServer(
      http.get(
        'https://api.pwnedpasswords.com/range/00000',
        createStreamResponder(['fo', 'o:30', '\r\nbar:20']),
      ),
      http.get('https://api.pwnedpasswords.com/range/00001', createStreamResponder(['bar', ':10'])),
      http.get(
        'https://api.pwnedpasswords.com/range/00002',
        createStreamResponder(['ba', 'z:10\r\n', 'quux:40']),
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
        { hash: '00000bar', occurrences: 20 },
        { hash: '00000foo', occurrences: 30 },
        { hash: '00002quux', occurrences: 40 },
      ]);
    });
  });
});
