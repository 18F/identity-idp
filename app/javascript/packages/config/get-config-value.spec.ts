import getConfigValue from './get-config-value';
import type { Config } from './get-config-value';

describe('getConfigValue', () => {
  const APP_NAME = 'app';
  const ANALYTICS_ENDPOINT = 'url';

  beforeEach(() => {
    const config = document.createElement('script');
    config.type = 'application/json';
    config.setAttribute('data-config', '');
    config.textContent = JSON.stringify({
      appName: APP_NAME,
      analyticsEndpoint: ANALYTICS_ENDPOINT,
    } as Config);
    document.body.appendChild(config);
  });

  it('returns the config value corresponding to the given key', () => {
    expect(getConfigValue('appName')).to.equal(APP_NAME);
    expect(getConfigValue('analyticsEndpoint')).to.equal(ANALYTICS_ENDPOINT);
  });
});
