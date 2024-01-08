import {
  isWebauthnPlatformAuthenticatorAvailable,
  isWebauthnPasskeySupported,
} from '@18f/identity-webauthn';

async function platformAuthenticatorAvailable() {
  const platformauthenticatorAvailableInput = document.getElementById(
    'platform_authenticator_available',
  ) as HTMLInputElement;
  if (!platformauthenticatorAvailableInput) {
    return;
  }
  if (isWebauthnPasskeySupported() && (await isWebauthnPlatformAuthenticatorAvailable())) {
    platformauthenticatorAvailableInput.value = 'true';
  } else {
    platformauthenticatorAvailableInput.value = 'false';
  }
}

platformAuthenticatorAvailable();
