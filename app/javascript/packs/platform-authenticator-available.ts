import {
  isWebauthnPlatformAuthenticatorAvailable,
  isWebauthnPasskeySupported,
} from '@18f/identity-webauthn';

async function platformAuthenticatorAvailable() {
  const platformAuthenticatorAvailableInput = document.getElementById(
    'platform_authenticator_available',
  ) as HTMLInputElement;
  if (!platformAuthenticatorAvailableInput) {
    return;
  }
  if (isWebauthnPasskeySupported() && (await isWebauthnPlatformAuthenticatorAvailable())) {
    platformAuthenticatorAvailableInput.value = 'true';
  } else {
    platformAuthenticatorAvailableInput.value = 'false';
  }
}

platformAuthenticatorAvailable();
