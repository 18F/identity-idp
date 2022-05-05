import { render } from 'react-dom';
import { VerifyFlow, SecretsContextProvider } from '@18f/identity-verify-flow';
import { s2ab } from '@18f/identity-secret-session-storage';

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
const initialValues = JSON.parse(initialValuesJSON);
const enabledStepNames = JSON.parse(enabledStepNamesJSON) as string[];

const camelCase = (string: string) =>
  string.replace(/[^a-z]([a-z])/gi, (_match, nextLetter) => nextLetter.toUpperCase());

const jwtData = JSON.parse(atob(initialValues.userBundleToken.split('.')[1]));
const pii = Object.fromEntries(
  Object.entries(jwtData.pii).map(([key, value]) => [camelCase(key), value]),
);
Object.assign(initialValues, pii);

function onComplete() {
  window.location.href = completionURL;
}

render(
  <SecretsContextProvider storeKey={storeKey}>
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
