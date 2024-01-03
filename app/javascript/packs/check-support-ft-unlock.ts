import { isWebauthnPlatformAuthenticatorAvailable } from '@18f/identity-webauthn';

async function checkSupportFtUnlock() {
  const platformauthenticatorAvailableInput = document.getElementById(
    'platform_authenticator_available',
  ) as HTMLInputElement;
  if (!platformauthenticatorAvailableInput) {
    return;
  }
  if (await isWebauthnPlatformAuthenticatorAvailable()) {
    platformauthenticatorAvailableInput.value = 'true';
  } else {
    platformauthenticatorAvailableInput.value = 'false';
  }
}

if (process.env.NODE_ENV !== 'test') {
  checkSupportFtUnlock();
}
