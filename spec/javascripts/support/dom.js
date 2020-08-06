import sinon from 'sinon';
import { JSDOM, ResourceLoader } from 'jsdom';

/**
 * Returns an instance of a JSDOM DOM instance configured for the test environment.
 *
 * @return {import('jsdom').JSDOM} DOM instance.
 */
export function createDOM() {
  const dom = new JSDOM('', {
    url: 'http://example.test',
    resources: new (class extends ResourceLoader {
      // eslint-disable-next-line class-methods-use-this
      fetch(url) {
        return url === 'about:blank'
          ? Promise.resolve(Buffer.from(''))
          : Promise.reject(new Error('Failed to load'));
      }
    })(),
    runScripts: 'dangerously',
  });

  // JSDOM doesn't implement scrollTo, and loudly complains (logs) when it's called, conflicting
  // with global log error capturing. This suppresses said logging.
  sinon
    .stub(dom.window, 'scrollTo')
    .withArgs(sinon.match.object)
    .throws(new Error())
    .withArgs(sinon.match.number, sinon.match.number)
    .callsFake((scrollX, scrollY) => Object.assign(dom.window, { scrollX, scrollY }));

  return dom;
}

/**
 * Test lifecycle helper which ensures a clean DOM document for each test case.
 */
export function useCleanDOM() {
  beforeEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
  });
}
