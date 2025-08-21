import getDefaultLoadPaths from './get-default-load-paths.js';

describe('getDefaultLoadPaths', () => {
  it('returns an empty array if no dependencies are in load paths', () => {
    const alwaysFalse = () => {
      false;
    };
    const result = getDefaultLoadPaths(alwaysFalse);

    expect(result).to.deep.equal([]);
  });

  context('with the Login.gov Design System as a dependency', () => {
    it('returns load paths for the Login.gov Design System', () => {
      const trueForLgds = (dependency) => dependency === '@18f/identity-design-system';
      const result = getDefaultLoadPaths(trueForLgds);

      expect(result).to.deep.equal(['node_modules/@18f/identity-design-system/packages']);
    });
  });

  context('with the U.S. Web Design System as a dependency', () => {
    it('returns load paths for the U.S. Web Design System', () => {
      const trueForUswds = (dependency) => dependency === '@uswds/uswds';
      const result = getDefaultLoadPaths(trueForUswds);

      expect(result).to.deep.equal(['node_modules/@uswds/uswds/packages']);
    });
  });
});
