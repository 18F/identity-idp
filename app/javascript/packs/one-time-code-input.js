/**
 * @typedef {CredentialsContainer & {
 *  get(options?: OTPCredentialRequestOptions): Promise<OTPCredential>
 * }} OTPCredentialsContainer
 *
 * @see https://wicg.github.io/web-otp/#API
 */

/**
 * @typedef {CredentialRequestOptions & {otp: { transport: string[] }}} OTPCredentialRequestOptions
 *
 * @see https://wicg.github.io/web-otp/#CredentialRequestOptions
 */

/**
 * @typedef {Credential & {code: string}} OTPCredential
 *
 * @see https://wicg.github.io/web-otp/#OTPCredential
 */

const input = document.querySelector('.one-time-code-input');

if (input && window.OTPCredential) {
  const controller = new AbortController();

  const form = input.closest('form');
  if (form) {
    form.addEventListener('submit', () => controller.abort());
  }

  /** @type {OTPCredentialsContainer} */ (navigator.credentials)
    .get({ otp: { transport: ['sms'] }, signal: controller.signal })
    .then((credential) => {
      input.value = credential.code;
      form?.submit();
    })
    .catch(() => {});
}
