/**
 * @typedef Polyfill
 *
 * @prop {()=>boolean} test Test function, returning true if feature is detected as supported.
 * @prop {()=>Promise} load Function to load polyfill module.
 */

/**
 * @typedef {"fetch"} SupportedPolyfills
 */

/**
 * @type {Record<SupportedPolyfills,Polyfill>}
 */
const POLYFILLS = {
  fetch: {
    test: () => 'fetch' in window,
    load: () => import(/* webpackChunkName: "whatwg-fetch" */ 'whatwg-fetch'),
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
