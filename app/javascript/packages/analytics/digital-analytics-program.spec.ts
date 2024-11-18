import { Worker } from 'node:worker_threads';
import { join } from 'node:path';
import { pathToFileURL } from 'node:url';

describe('digital analytics program', () => {
  it('parses without syntax error', async () => {
    // Future: Replace with Promise.withResolvers once supported
    // See: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/withResolvers
    let resolve;
    const promise = new Promise((_resolve) => {
      resolve = _resolve;
    });

    // Reference: https://github.com/nodejs/node/issues/30682
    const toDataURL = (source: string) => new URL(`data:text/javascript,${encodeURIComponent(source)}`);
    const url = pathToFileURL(join(__dirname, './digital-analytics-program.js'));
    const code = `await import(${JSON.stringify(url)});`;
    new Worker(toDataURL(code)).on('error', (error) => {
      expect(error).not.to.be.instanceOf(SyntaxError);
      resolve();
    });

    await promise;
  });
});
