import { render } from 'react-dom';
import { VerifyFlow, SecretValues, SecretsContextProvider } from '@18f/identity-verify-flow';
import SecretSessionStorage, { encode } from '@18f/identity-secret-session-storage';

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
} = appRoot.dataset;

const initialValues = JSON.parse(initialValuesJSON);
const enabledStepNames = JSON.parse(enabledStepNamesJSON) as string[];

function onComplete() {
  window.location.href = completionURL;
}

(async () => {
  const key = encode(atob(appRoot.dataset.storeKey!));
  const iv = encode(atob(appRoot.dataset.storeIv!));

  const storage = new SecretSessionStorage<SecretValues>();
  storage.storageKey = 'verify';
  storage.key = await crypto.subtle.importKey('raw', key, 'AES-GCM', true, ['encrypt', 'decrypt']);
  storage.iv = iv;
  await storage.load();

  render(
    <SecretsContextProvider value={storage}>
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
