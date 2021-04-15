/**
 * @see https://wicg.github.io/web-otp/#API
 */
interface OTPCredentialsContainer extends CredentialsContainer {
  get(options?: OTPCredentialRequestOptions): Promise<OTPCredential>;
}

/**
 * @see https://wicg.github.io/web-otp/#CredentialRequestOptions
 */
interface OTPCredentialRequestOptions extends CredentialRequestOptions {
  otp: { transport: string[] };
}

/**
 * @see https://wicg.github.io/web-otp/#OTPCredential
 */
interface OTPCredential extends Credential {
  code: string;
}
