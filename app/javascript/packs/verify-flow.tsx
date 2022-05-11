import { render } from 'react-dom';
import { VerifyFlow, SecretsContextProvider } from '@18f/identity-verify-flow';
import SecretSessionStorage, { s2ab } from '@18f/identity-secret-session-storage';
import type { SecretValues, VerifyFlowValues } from '@18f/identity-verify-flow';

interface AppRootValues {
  /**
   * JSON-encoded object of initial application data.
   */
  initialValues: string;

  /**
   * JSON-encoded array of enabled step names.
   */
  enabledStepNames: string;

  /**
   * The path to which the current step is appended to create the current step URL.
   */
  basePath: string;

  /**
   * Application name.
   */
  appName: string;

  /**
   * URL to which user should be redirected after completing the form.
   */
  completionUrl: string;

  /**
   * Base64-encoded encryption key for secret session store.
   */
  storeKey: string;

  /**
   * Signed JWT containing user data.
   */
  userBundleToken: string;
}

interface AppRootElement extends HTMLElement {
  dataset: DOMStringMap & AppRootValues;
}

const appRoot = document.getElementById('app-root') as AppRootElement;
const {
  initialValues: initialValuesJSON,
  enabledStepNames: enabledStepNamesJSON,
  basePath,
  appName,
  completionUrl: completionURL,
  storeKey: storeKeyBase64,
} = appRoot.dataset;
const storeKey = s2ab(atob(storeKeyBase64));
const initialValues: Partial<VerifyFlowValues> = JSON.parse(initialValuesJSON);
const enabledStepNames = JSON.parse(enabledStepNamesJSON) as string[];

const camelCase = (string: string) =>
  string.replace(/[^a-z]([a-z])/gi, (_match, nextLetter) => nextLetter.toUpperCase());

const mapKeys = (object: object, mapKey: (key: string) => string) =>
  Object.entries(object).map(([key, value]) => [mapKey(key), value]);

function onComplete() {
  window.location.href = completionURL;
}

const storage = new SecretSessionStorage<SecretValues>('verify');

(async () => {
  const cryptoKey = await crypto.subtle.importKey('raw', storeKey, 'AES-GCM', true, [
    'encrypt',
    'decrypt',
  ]);
  storage.key = cryptoKey;
  await storage.load();
  if (initialValues.userBundleToken) {
    await storage.setItem('userBundleToken', initialValues.userBundleToken);
  }

  const userBundleToken = storage.getItem('userBundleToken');
  if (userBundleToken) {
    const jwtData = JSON.parse(atob(userBundleToken.split('.')[1]));
    const pii = Object.fromEntries(mapKeys(jwtData.pii, camelCase));
    Object.assign(initialValues, pii);
  }

  render(
    <SecretsContextProvider storage={storage}>
      <VerifyFlow
        initialValues={initialValues}
        enabledStepNames={enabledStepNames}
        basePath={basePath}
        appName={appName}
        onComplete={onComplete}
      />
    </SecretsContextProvider>,
    appRoot,
  );
})();
