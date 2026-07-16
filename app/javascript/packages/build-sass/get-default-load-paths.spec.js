import getDefaultLoadPaths from './get-default-load-paths.js';

describe('getDefaultLoadPaths', () => {
  it('returns an empty array if no dependencies are in load paths', () => {
    const alwaysFalse = () => {
      false;
    };
    const result = getDefaultLoadPaths(alwaysFalse);

    expect(result).to.deep.equal([]);
  });
});
