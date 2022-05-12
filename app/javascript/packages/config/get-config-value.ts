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
let config: Config;

/**
 * Returns the value associated as initialized through page configuration, if available.
 *
 * @param key Key for which to return value.
 *
 * @return Value, if exists.
 */
function getConfigValue<K extends keyof Config>(key: K): Config[K] {
  if (config === undefined) {
    config = JSON.parse(document.querySelector('[data-config]')?.textContent || '');
  }

  return config[key];
}

export default getConfigValue;
