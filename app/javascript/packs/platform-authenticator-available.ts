import {
  isWebauthnPlatformAuthenticatorAvailable,
  isWebauthnPasskeySupported,
} from '@18f/identity-webauthn';

export async function initialize() {
  const input = document.getElementById('platform_authenticator_available') as HTMLInputElement;
  if (isWebauthnPasskeySupported() && (await isWebauthnPlatformAuthenticatorAvailable())) {
    input.value = 'true';
  }
}

if (process.env.NODE_ENV !== 'test') {
  initialize();
}
