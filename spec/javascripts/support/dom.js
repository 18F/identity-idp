import { JSDOM, ResourceLoader } from 'jsdom';

/**
 * Returns an instance of a JSDOM DOM instance configured for the test environment.
 *
 * @return {import('jsdom').JSDOM} DOM instance.
 */
export function createDOM() {
  return new JSDOM('', {
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
