import sinon from 'sinon';
import { JSDOM, ResourceLoader } from 'jsdom';
import matchMediaPolyfill from 'mq-polyfill';

/**
 * Returns an instance of a JSDOM DOM instance configured for the test environment.
 *
 * @return {import('jsdom').JSDOM} DOM instance.
 */
export function createDOM() {
  const dom = new JSDOM('', {
    url: 'http://example.test',
    resources: new (class extends ResourceLoader {
      /**
       * @param {string} url
       * @param {import('jsdom').FetchOptions} options
       */
      fetch(url, options) {
        if (url.startsWith('data:') && options.element instanceof window.HTMLImageElement) {
          const [header, content] = url.split(',');
          const isBase64 = header.endsWith(';base64');
          return Promise.resolve(Buffer.from(content, isBase64 ? 'base64' : 'utf-8'));
        }

        return url === 'about:blank'
          ? Promise.resolve(Buffer.from(''))
          : Promise.reject(new Error('Failed to load'));
      }
    })(),
    runScripts: 'dangerously',
  });

  // JSDOM doesn't implement `offsetParent`, which is used by some third-party libraries to detect
  // if a node is visible (e.g. `tabbable`). This is enough to return a sensible value. Note that
  // this is not spec-compliant to what defines an offsetParent.
  //
  // See: https://github.com/jsdom/jsdom/issues/1261
  Object.defineProperty(dom.window.HTMLElement.prototype, 'offsetParent', {
    get() {
      return this.parentNode;
    },
  });

  matchMediaPolyfill(dom.window);

  dom.window.resizeTo = function (width, height) {
    Object.assign(this, {
      innerWidth: width,
      innerHeight: height,
      outerWidth: width,
      outerHeight: height,
    }).dispatchEvent(new this.Event('resize'));
  };

  // See: https://github.com/jsdom/jsdom/issues/1695
  dom.window.Element.prototype.scrollIntoView = () => {};

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
    window.location.hash = '';
  });
}
