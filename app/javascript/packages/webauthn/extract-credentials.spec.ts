import extractCredentials from './extract-credentials';

describe('extractCredentials', () => {
  it('returns an array of converted credential descriptors', () => {
    const result = extractCredentials(['Y3JlZGVudGlhbDEyMw==', 'Y3JlZGVudGlhbDQ1Ng==']);

    expect(result).to.deep.equal([
      {
        id: Uint8Array.from([99, 114, 101, 100, 101, 110, 116, 105, 97, 108, 49, 50, 51]).buffer,
        type: 'public-key',
      },
      {
        id: Uint8Array.from([99, 114, 101, 100, 101, 110, 116, 105, 97, 108, 52, 53, 54]).buffer,
        type: 'public-key',
      },
    ]);
  });
});
