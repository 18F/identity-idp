import isSafe from './is-safe';

describe('isSafe', () => {
  it('returns true if no error is thrown in invocation', () => {
    const result = isSafe(() => '');

    expect(result).to.equal(true);
  });

  it('returns false if error is thrown in invocation', () => {
    const result = isSafe(() => {
      throw new Error();
    });

    expect(result).to.be.false();
  });
});
