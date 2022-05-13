import { addSearchParams } from './index';

describe('addSearchParams', () => {
  it('adds search params to an existing URL', () => {
    const url = 'https://example.com/?a=1&b=1';
    const expected = 'https://example.com/?a=1&b=2&c=3';

    const actual = addSearchParams(url, { b: 2, c: 3 });

    expect(actual).to.equal(expected);
  });

  it('adds search params to a path', () => {
    const url = '/example';
    const expected = '/example?a=1&b=2&c=3';

    const actual = addSearchParams(url, { a: 1, b: 2, c: 3 });

    expect(actual).to.equal(expected);
  });

  it('retains hash fragment unaltered', () => {
    const url = '?a=1#example';
    const expected = '?a=1&b=2#example';

    const actual = addSearchParams(url, { b: 2 });

    expect(actual).to.equal(expected);
  });

  it('adds search params to an existing search fragment', () => {
    const params = '?a=1&b=1';
    const expected = '?a=1&b=2&c=3';

    const actual = addSearchParams(params, { b: 2, c: 3 });

    expect(actual).to.equal(expected);
  });

  it('adds search params to an empty URL', () => {
    const params = '';
    const expected = '?a=1&b=2&c=3';

    const actual = addSearchParams(params, { a: 1, b: 2, c: 3 });

    expect(actual).to.equal(expected);
  });
});
