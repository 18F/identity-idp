import isUserVerificationScreenLockError from './is-user-verification-screen-lock-error';

/**
 * Set of expected DOM exceptions, which occur based on some user behavior that is not noteworthy:
 *
 * - Declining permissions
 * - Timeout due to inactivity
 * - Invalid state such as duplicate key enrollment
 *
 * @see https://webidl.spec.whatwg.org/#idl-DOMException
 */
const EXPECTED_DOM_EXCEPTIONS: Set<string> = new Set([
  'NotAllowedError',
  'TimeoutError',
  'InvalidStateError',
]);

interface IsExpectedErrorOptions {
  /**
   * Whether the error happened in the context of a verification ceremony.
   */
  isVerifying: boolean;
}

function isExpectedWebauthnError(
  error: Error,
  { isVerifying }: Partial<IsExpectedErrorOptions> = {},
): boolean {
  return (
    (error instanceof DOMException && EXPECTED_DOM_EXCEPTIONS.has(error.name)) ||
    (!!isVerifying && isUserVerificationScreenLockError(error))
  );
}

export default isExpectedWebauthnError;
