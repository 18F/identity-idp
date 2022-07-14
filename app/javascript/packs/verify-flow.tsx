import { render, unmountComponentAtNode } from 'react-dom';
import {
  VerifyFlow,
  SecretsContextProvider,
  decodeUserBundle,
  AddressVerificationMethod,
  ErrorStatusPage,
  FlowContext,
} from '@18f/identity-verify-flow';
import { trackError } from '@18f/identity-analytics';
import SecretSessionStorage, { s2ab } from '@18f/identity-secret-session-storage';
import type { SecretValues, VerifyFlowValues, FlowContextValue } from '@18f/identity-verify-flow';

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
   * URL to path for session cancel.
   */
  cancelUrl: string;

  /**
   * URL to in-person proofing alternative flow, if enabled.
   */
  inPersonUrl: string | null;

  /**
   * Base64-encoded encryption key for secret session store.
   */
  storeKey: string;
}

interface AppRootElement extends HTMLElement {
  dataset: DOMStringMap & AppRootValues;
}

const camelCase = (string: string) =>
  string.replace(/[^a-z]([a-z])/gi, (_match, nextLetter) => nextLetter.toUpperCase());

const mapKeys = (object: object, mapKey: (key: string) => string) =>
  Object.entries(object).map(([key, value]) => [mapKey(key), value]);

export async function initialize() {
  const storage = new SecretSessionStorage<SecretValues>('verify');
  const appRoot = document.getElementById('app-root') as AppRootElement;
  const {
    initialValues: initialValuesJSON,
    enabledStepNames: enabledStepNamesJSON,
    basePath,
    cancelUrl: cancelURL,
    inPersonUrl: inPersonURL,
    storeKey: storeKeyBase64,
  } = appRoot.dataset;
  const initialValues: Partial<VerifyFlowValues> = JSON.parse(initialValuesJSON);
  const enabledStepNames = JSON.parse(enabledStepNamesJSON) as string[];

  const tearDown = () => unmountComponentAtNode(appRoot);

  let cryptoKey: CryptoKey;
  let initialAddressVerificationMethod: AddressVerificationMethod | undefined;
  try {
    const storeKey = s2ab(atob(storeKeyBase64));
    cryptoKey = await window.crypto.subtle.importKey('raw', storeKey, 'AES-GCM', true, [
      'encrypt',
      'decrypt',
    ]);
    storage.key = cryptoKey;
    await storage.load();
    const userBundleToken = initialValues.userBundleToken as string;
    await storage.setItem('userBundleToken', userBundleToken);
    const userBundle = decodeUserBundle(userBundleToken);
    if (userBundle) {
      Object.assign(initialValues, Object.fromEntries(mapKeys(userBundle.pii, camelCase)));
      initialAddressVerificationMethod = userBundle.metadata.address_verification_mechanism;
    }
  } catch (error) {
    trackError(error);
    render(
      <FlowContext.Provider value={{ inPersonURL } as FlowContextValue}>
        <ErrorStatusPage />
      </FlowContext.Provider>,
      appRoot,
    );
    return tearDown;
  }

  function onComplete({ completionURL }: VerifyFlowValues) {
    storage.clear();
    if (completionURL) {
      window.location.href = completionURL;
    }
  }

  window.addEventListener('lg:session-timeout', () => storage.clear());

  render(
    <SecretsContextProvider storage={storage}>
      <VerifyFlow
        initialValues={initialValues}
        enabledStepNames={enabledStepNames}
        cancelURL={cancelURL}
        inPersonURL={inPersonURL}
        basePath={basePath}
        onComplete={onComplete}
        initialAddressVerificationMethod={initialAddressVerificationMethod}
      />
    </SecretsContextProvider>,
    appRoot,
  );

  return tearDown;
}

if (process.env.NODE_ENV !== 'test') {
  initialize();
}
