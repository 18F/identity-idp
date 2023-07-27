/**
 * Set of expected DOM exceptions, which occur based on some user behavior that is not noteworthy,
 * such as declining permissions or timeout due to inactivity.
 *
 * @see https://webidl.spec.whatwg.org/#idl-DOMException
 */
const EXPECTED_DOM_EXCEPTIONS: Set<string> = new Set(['NotAllowedError', 'TimeoutError']);

const isExpectedWebauthnError = (error: Error): boolean =>
  error instanceof DOMException && EXPECTED_DOM_EXCEPTIONS.has(error.name);

export default isExpectedWebauthnError;
