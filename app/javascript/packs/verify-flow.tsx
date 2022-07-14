import { render } from 'react-dom';
import {
  VerifyFlow,
  SecretsContextProvider,
  AddressVerificationMethod,
} from '@18f/identity-verify-flow';
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
   * URL to path for session restart.
   */
  startOverUrl: string;

  /**
   * URL to path for session cancel.
   */
  cancelUrl: string;

  /**
   * Base64-encoded encryption key for secret session store.
   */
  storeKey: string;
}

interface UserBundleMetadata {
  address_verification_mechanism: AddressVerificationMethod;
}

interface UserBundle {
  pii: Record<string, any>;

  metadata: UserBundleMetadata;
}

interface AppRootElement extends HTMLElement {
  dataset: DOMStringMap & AppRootValues;
}

const appRoot = document.getElementById('app-root') as AppRootElement;
const {
  initialValues: initialValuesJSON,
  enabledStepNames: enabledStepNamesJSON,
  basePath,
  startOverUrl: startOverURL,
  cancelUrl: cancelURL,
  storeKey: storeKeyBase64,
} = appRoot.dataset;
const storeKey = s2ab(atob(storeKeyBase64));
const initialValues: Partial<VerifyFlowValues> = JSON.parse(initialValuesJSON);
const enabledStepNames = JSON.parse(enabledStepNamesJSON) as string[];

const camelCase = (string: string) =>
  string.replace(/[^a-z]([a-z])/gi, (_match, nextLetter) => nextLetter.toUpperCase());

const mapKeys = (object: object, mapKey: (key: string) => string) =>
  Object.entries(object).map(([key, value]) => [mapKey(key), value]);

const storage = new SecretSessionStorage<SecretValues>('verify');

(async () => {
  const cryptoKey = await crypto.subtle.importKey('raw', storeKey, 'AES-GCM', true, [
    'encrypt',
    'decrypt',
  ]);
  storage.key = cryptoKey;
  await storage.load();
  const userBundleToken = initialValues.userBundleToken as string;
  await storage.setItem('userBundleToken', userBundleToken);
  const { pii, metadata } = JSON.parse(atob(userBundleToken.split('.')[1])) as UserBundle;
  Object.assign(initialValues, Object.fromEntries(mapKeys(pii, camelCase)));

  function onComplete({ completionURL }: VerifyFlowValues) {
    storage.clear();
    if (completionURL) {
      window.location.href = completionURL;
    }
  }

  render(
    <SecretsContextProvider storage={storage}>
      <VerifyFlow
        initialValues={initialValues}
        enabledStepNames={enabledStepNames}
        startOverURL={startOverURL}
        cancelURL={cancelURL}
        basePath={basePath}
        onComplete={onComplete}
        initialAddressVerificationMethod={metadata.address_verification_mechanism}
      />
    </SecretsContextProvider>,
    appRoot,
  );
})();
