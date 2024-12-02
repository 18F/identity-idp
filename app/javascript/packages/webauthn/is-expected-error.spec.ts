import isExpectedWebauthnError from './is-expected-error';
import { SCREEN_LOCK_ERROR } from './is-user-verification-screen-lock-error';

describe('isExpectedWebauthnError', () => {
  it('returns false for any error other than DOMException', () => {
    const error = new TypeError();
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.false();
  });

  it('returns false for instance of DOMException of an unexpected name', () => {
    const error = new DOMException('', 'UnknownError');
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.false();
  });

  it('returns true for instance of DOMException of an expected name', () => {
    const error = new DOMException('', 'NotAllowedError');
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.true();
  });

  it('returns false for a screen lock error', () => {
    const error = new DOMException(SCREEN_LOCK_ERROR, 'NotSupportedError');
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.false();
  });

  it('returns true for a screen lock error specified to have occurred during verification', () => {
    const error = new DOMException(SCREEN_LOCK_ERROR, 'NotSupportedError');
    const result = isExpectedWebauthnError(error, { isVerifying: true });

    expect(result).to.be.true();
  });

  it('returns true for a NotReadableError Android credential manager incompatibility', () => {
    const error = new DOMException(
      'An unknown error occurred while talking to the credential manager.',
      'NotReadableError',
    );
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.true();
  });

  it('returns false for NotSupportedError when not during verification', () => {
    const error = new DOMException(
      'The user agent does not support public key credentials.',
      'NotSupportedError',
    );
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.false();
  });

  it('returns true for NotSupportedError during verification', () => {
    const error = new DOMException(
      'The user agent does not support public key credentials.',
      'NotSupportedError',
    );
    const result = isExpectedWebauthnError(error, { isVerifying: true });

    expect(result).to.be.true();
  });
});
