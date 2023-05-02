import { resolveObjectValues, series } from '@18f/identity-document-capture/components/submission';

describe('resolveObjectValues', () => {
  it('returns an object with resolved values', async () => {
    const result = await resolveObjectValues({
      a: 1,
      b: Promise.resolve(2),
      c: 3,
    });

    expect(result).to.deep.equal({
      a: 1,
      b: 2,
      c: 3,
    });
  });
});

describe('series', () => {
  it('runs promise in chain series', async () => {
    const run = series(
      (current) => Promise.resolve(`${current}b`),
      (current) => Promise.resolve(`${current}c`),
    );

    const result = await run('a');

    expect(result).to.equal('abc');
  });
});
