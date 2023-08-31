export { default as isWebauthnSupported } from './is-webauthn-supported';
export { default as enrollWebauthnDevice } from './enroll-webauthn-device';
export { default as extractCredentials } from './extract-credentials';
export { default as verifyWebauthnDevice } from './verify-webauthn-device';
export * from './converters';

export type { VerifyCredentialDescriptor } from './verify-webauthn-device';
