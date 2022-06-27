import sinon from 'sinon';
import { JSDOM, ResourceLoader } from 'jsdom';
import matchMediaPolyfill from 'mq-polyfill';
import * as clipboard from 'clipboard-polyfill'; // See: https://github.com/jsdom/jsdom/issues/1568

const TEST_URL = 'http://example.test';

/**
 * Returns an instance of a JSDOM DOM instance configured for the test environment.
 *
 * @return {import('jsdom').JSDOM} DOM instance.
 */
export function createDOM() {
  const dom = new JSDOM('<!doctype html><html lang="en"><head><title>JSDOM</title></head></html>', {
    url: TEST_URL,
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

  dom.window.navigator.clipboard = clipboard;

  // See: https://github.com/jsdom/jsdom/issues/1695
  dom.window.Element.prototype.scrollIntoView = () => {};

  // JSDOM doesn't implement scrollTo, and loudly complains (logs) when it's called, conflicting
  // with global log error capturing. This suppresses said logging.
  sinon
    .stub(dom.window, 'scrollTo')
    .callsFake((scrollX, scrollY) => Object.assign(dom.window, { scrollX, scrollY }));

  // If a script tag is added to the page, execute its callbacks as a successful or failed load,
  // based on whether the `src` is `about:blank`.
  new dom.window.MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node instanceof dom.window.HTMLScriptElement) {
          if (node.src === 'about:blank') {
            if (typeof node.onload === 'function') {
              node.onload();
            }
          } else if (typeof node.onerror === 'function') {
            node.onerror();
          }
        }
      });
    });
  }).observe(dom.window.document.body, { childList: true, subtree: true });

  return dom;
}

/**
 * Test lifecycle helper which ensures a clean DOM document for each test case.
 *
 * @param {JSDOM} dom instance.
 */
export function useCleanDOM(dom) {
  beforeEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    document.documentElement.lang = 'en';
    window.history.replaceState(null, '', TEST_URL);
    window.location.pathname = '';
    window.location.hash = '';
    dom.cookieJar.removeAllCookiesSync();
  });
}
