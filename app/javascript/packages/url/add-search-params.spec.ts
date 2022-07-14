import addSearchParams from './add-search-params';

describe('addSearchParams', () => {
  it('adds search params to an existing URL', () => {
    const url = 'https://example.com/?a=1&b=1';
    const expected = 'https://example.com/?a=1&b=2&c=3';

    const actual = addSearchParams(url, { b: 2, c: 3 });

    expect(actual).to.equal(expected);
  });

  it('accepts URL as a path', () => {
    const url = '/example';
    const expected = `${window.location.origin}/example?a=1&b=2&c=3`;

    const actual = addSearchParams(url, { a: 1, b: 2, c: 3 });

    expect(actual).to.equal(expected);
  });

  it('adds search params to an empty URL', () => {
    const params = '';
    const expected = `${window.location.origin}/?a=1&b=2&c=3`;

    const actual = addSearchParams(params, { a: 1, b: 2, c: 3 });

    expect(actual).to.equal(expected);
  });
});
