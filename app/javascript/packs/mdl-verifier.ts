import * as MATTRVerifierSDK from '@mattrglobal/verifier-sdk-web';

interface Config {
  tenantUrl: string;
  applicationId: string;
  callbackPath: string;
  challenge: string;
  errorMessage: string;
  csrfToken: string;
}

interface Elements {
  button: HTMLButtonElement;
  errorDiv: HTMLElement;
  loadingDiv: HTMLElement;
}

function showError(elements: Elements, message: string) {
  const text = elements.errorDiv.querySelector('.usa-alert__text');
  if (text) {
    text.textContent = message;
  }
  elements.errorDiv.classList.remove('display-none');
  elements.loadingDiv.classList.add('display-none');
  elements.button.classList.remove('display-none');
}

function hideError(elements: Elements) {
  elements.errorDiv.classList.add('display-none');
}

async function postSessionId(config: Config, elements: Elements, sessionId: string) {
  const response = await fetch(config.callbackPath, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': config.csrfToken,
    },
    body: JSON.stringify({ session_id: sessionId }),
  });

  const data = await response.json();

  if (data.status === 'complete' && data.redirect) {
    window.location.href = data.redirect;
  } else {
    showError(elements, data.message || config.errorMessage);
  }
}

async function startFlow(config: Config, elements: Elements) {
  hideError(elements);
  elements.button.classList.add('display-none');
  elements.loadingDiv.classList.remove('display-none');

  const options = {
    credentialQuery: [
      {
        profile: 'mobile',
        docType: 'org.iso.18013.5.1.mDL',
        nameSpaces: {
          'org.iso.18013.5.1': {
            given_name: {},
            family_name: {},
            birth_date: {},
            document_number: {},
            resident_address: {},
            resident_city: {},
            resident_state: {},
            resident_postal_code: {},
            issue_date: {},
            expiry_date: {},
            issuing_authority: {},
          },
        },
      },
    ],
    challenge: config.challenge,
    openid4vpConfiguration: {
      redirectUri: window.location.origin + window.location.pathname,
    },
  };

  const results = await MATTRVerifierSDK.requestCredentials(options as any);

  if (results.isOk()) {
    await postSessionId(config, elements, results.value.sessionId);
  } else {
    showError(elements, results.error?.message || config.errorMessage);
  }
}

async function handleRedirect(config: Config, elements: Elements) {
  const results = await MATTRVerifierSDK.handleRedirectCallback();

  if (results.isOk() && results.value.sessionId) {
    elements.button.classList.add('display-none');
    elements.loadingDiv.classList.remove('display-none');
    await postSessionId(config, elements, results.value.sessionId);
  } else if (results.isErr()) {
    showError(elements, results.error?.message || config.errorMessage);
  }
}

const root = document.querySelector<HTMLElement>('[data-mdl-verifier]');

if (root) {
  const config: Config = {
    tenantUrl: root.dataset.mattrTenantUrl as string,
    applicationId: root.dataset.mattrApplicationId as string,
    callbackPath: root.dataset.callbackPath as string,
    challenge: root.dataset.challenge as string,
    errorMessage: root.dataset.errorMessage as string,
    csrfToken: document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
  };

  const elements: Elements = {
    button: document.getElementById('mdl-verify-button') as HTMLButtonElement,
    errorDiv: document.getElementById('mdl-error') as HTMLElement,
    loadingDiv: document.getElementById('mdl-loading') as HTMLElement,
  };

  MATTRVerifierSDK.initialize({
    apiBaseUrl: config.tenantUrl,
    applicationId: config.applicationId,
  });

  if (MATTRVerifierSDK.isDigitalCredentialsApiSupported()) {
    console.log('[mdl-verifier] DC API supported');
  }

  if (window.location.hash) {
    handleRedirect(config, elements);
  }

  elements.button?.addEventListener('click', () => startFlow(config, elements));
}
