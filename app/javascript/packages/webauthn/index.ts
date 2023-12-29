export { default as enrollWebauthnDevice } from './enroll-webauthn-device';
export { default as extractCredentials } from './extract-credentials';
export { default as verifyWebauthnDevice } from './verify-webauthn-device';
export { default as isExpectedWebauthnError } from './is-expected-error';
export { default as isWebauthnPlatformAuthenticatorAvailable } from './is-webauthn-platform-authenticator-available'
export * from './converters';

export type { VerifyCredentialDescriptor } from './verify-webauthn-device';
