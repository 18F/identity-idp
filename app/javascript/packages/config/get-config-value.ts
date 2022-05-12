/**
 * Supported page configuration values.
 */
export interface Config {
  /**
   * Application name.
   */
  appName: string;

  /**
   * URL for analytics logging endpoint.
   */
  analyticsEndpoint: string;
}

/**
 * Cached configuration.
 */
let cache: Partial<Config>;

/**
 * Whether configuration should be cached in this environment.
 */
const isCacheEnvironment = process.env.NODE_ENV !== 'test';

/**
 * Returns the value associated as initialized through page configuration, if available.
 *
 * @param key Key for which to return value.
 *
 * @return Value, if exists.
 */
function getConfigValue<K extends keyof Config>(key: K): Config[K] | undefined {
  if (cache === undefined || !isCacheEnvironment) {
    try {
      cache = JSON.parse(document.querySelector('[data-config]')?.textContent || '');
    } catch {
      cache = {};
    }
  }

  return cache[key];
}

export default getConfigValue;
