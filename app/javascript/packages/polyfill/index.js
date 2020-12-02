/**
 * @typedef Polyfill
 *
 * @prop {()=>boolean} test Test function, returning true if feature is detected as supported.
 * @prop {()=>Promise} load Function to load polyfill module.
 */

/**
 * @typedef {"fetch"|"element-closest"|"classlist"|"crypto"|"custom-event"} SupportedPolyfills
 */

/**
 * @type {Record<SupportedPolyfills,Polyfill>}
 */
const POLYFILLS = {
  fetch: {
    test: () => 'fetch' in window,
    load: () => import(/* webpackChunkName: "whatwg-fetch" */ 'whatwg-fetch'),
  },
  'element-closest': {
    test: () => !!Element.prototype.closest,
    load: () => import(/* webpackChunkName: "element-closest" */ 'element-closest'),
  },
  classlist: {
    test: () => 'classList' in Element.prototype,
    load: () => import(/* webpackChunkName: "classlist-polyfill" */ 'classlist-polyfill'),
  },
  crypto: {
    test: () => 'crypto' in window,
    load: () => import(/* webpackChunkName: "webcrypto-shim" */ 'webcrypto-shim'),
  },
  'custom-event': {
    test() {
      try {
        // eslint-disable-next-line no-new
        new window.CustomEvent('test');
        return true;
      } catch {
        return false;
      }
    },
    load: () => import(/* webpackChunkName: "custom-event-polyfill" */ 'custom-event-polyfill'),
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
