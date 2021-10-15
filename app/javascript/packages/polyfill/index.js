import isSafe from './is-safe';

/**
 * @typedef Polyfill
 *
 * @prop {()=>boolean} test Test function, returning true if feature is detected as supported.
 * @prop {()=>Promise} load Function to load polyfill module.
 */

/**
 * @typedef {"fetch"|"classlist"|"crypto"|"custom-elements"|"custom-event"|"url"} SupportedPolyfills
 */

/**
 * @type {Record<SupportedPolyfills,Polyfill>}
 */
const POLYFILLS = {
  fetch: {
    test: () => 'fetch' in window,
    load: () => import(/* webpackChunkName: "whatwg-fetch" */ 'whatwg-fetch'),
  },
  classlist: {
    test: () => 'classList' in Element.prototype,
    load: () => import(/* webpackChunkName: "classlist-polyfill" */ 'classlist-polyfill'),
  },
  crypto: {
    test: () => 'crypto' in window,
    load: () => import(/* webpackChunkName: "webcrypto-shim" */ 'webcrypto-shim'),
  },
  'custom-elements': {
    test: () => 'customElements' in window,
    load: () =>
      import(/* webpackChunkName: "custom-elements-polyfill" */ '@webcomponents/custom-elements'),
  },
  'custom-event': {
    test: () => isSafe(() => new window.CustomEvent('test')),
    load: () => import(/* webpackChunkName: "custom-event-polyfill" */ 'custom-event-polyfill'),
  },
  url: {
    test: () => isSafe(() => new URL('http://example.com')) && isSafe(() => new URLSearchParams()),
    load: () => import(/* webpackChunkName: "js-polyfills-url" */ 'js-polyfills/url'),
  },
};

/**
 * Given an array of supported polyfill names, loads polyfill if necessary. Returns a promise which
 * resolves once all have been loaded.
 *
 * @param {SupportedPolyfills[]} polyfills Names of polyfills to load, if necessary.
 *
 * @return {Promise}
 */
export function loadPolyfills(polyfills) {
  return Promise.all(
    polyfills.map((name) => {
      const { test, load } = POLYFILLS[name];
      return test() ? Promise.resolve() : load();
    }),
  );
}
