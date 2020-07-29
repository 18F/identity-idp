import { JSDOM, ResourceLoader } from 'jsdom';

/**
 * Returns an instance of a JSDOM DOM instance configured for the test environment.
 *
 * @return {import('jsdom').JSDOM} DOM instance.
 */
export function createDOM() {
  return new JSDOM('', {
    url: 'http://example.test',
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
