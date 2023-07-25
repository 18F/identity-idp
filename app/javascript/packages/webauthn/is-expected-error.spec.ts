import isExpectedWebauthnError from './is-expected-error';

describe('isExpectedWebauthnError', () => {
  it('returns false for any error other than DOMException', () => {
    const error = new TypeError();
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.false();
  });

  it('returns true for instance of DOMException', () => {
    const error = new DOMException('', 'NotAllowedError');
    const result = isExpectedWebauthnError(error);

    expect(result).to.be.true();
  });
});
