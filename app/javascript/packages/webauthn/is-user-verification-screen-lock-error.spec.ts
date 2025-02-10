import isUserVerificationScreenLockError, {
  SCREEN_LOCK_ERROR,
} from './is-user-verification-screen-lock-error';

describe('isUserVerificationScreenLockError', () => {
  it('returns false for an error that is not a screen lock error', () => {
    const error = new DOMException('', 'NotSupportedError');

    expect(isUserVerificationScreenLockError(error)).to.be.false();
  });

  it('returns true for an error that is a screen lock error', () => {
    const error = new DOMException(SCREEN_LOCK_ERROR, 'NotSupportedError');

    expect(isUserVerificationScreenLockError(error)).to.be.true();
  });
});
