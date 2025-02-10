import isUserVerificationScreenLockError from './is-user-verification-screen-lock-error';

/**
 * Functions to test whether an error is expected and should not be logged for further analysis.
 */
const EXPECTED_ERRORS: Array<(error: Error, options: IsExpectedErrorOptions) => boolean> = [
  // A user who is unable to complete due to following DOMException reasons is not noteworthy:
  //
  // - Declining permissions
  // - Timeout due to inactivity
  // - Invalid state such as duplicate key enrollment
  (error) =>
    error.name === 'NotAllowedError' ||
    error.name === 'TimeoutError' ||
    error.name === 'InvalidStateError',
  // Some indication of incompatibilities on specific Android devices, either phone itself or
  // through credential manager.
  //
  // See: https://community.bitwarden.com/t/android-mobile-yubikey-5-nfc-webauth/51732
  // See: https://www.reddit.com/r/GooglePixel/comments/17enqf3/pixel_7_pro_unable_to_setup_passkeys/
  (error) =>
    error.name === 'NotReadableError' &&
    error.message === 'An unknown error occurred while talking to the credential manager.',
  // A user can choose to authenticate with Face or Touch Unlock from another device from what
  // they set up from, which may not necessarily support platform authenticators.
  (error, { isVerifying }) => isVerifying && isUserVerificationScreenLockError(error),
  (error, { isVerifying }) =>
    isVerifying &&
    error.name === 'NotSupportedError' &&
    error.message === 'The user agent does not support public key credentials.',
];

interface IsExpectedErrorOptions {
  /**
   * Whether the error happened in the context of a verification ceremony.
   */
  isVerifying: boolean;
}

const isExpectedWebauthnError = (
  error: Error,
  { isVerifying = false }: Partial<IsExpectedErrorOptions> = {},
): boolean => EXPECTED_ERRORS.some((isExpected) => isExpected(error, { isVerifying }));

export default isExpectedWebauthnError;
