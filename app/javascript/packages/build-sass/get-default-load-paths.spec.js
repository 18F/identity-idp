import getDefaultLoadPaths from './get-default-load-paths.js';

describe('getDefaultLoadPaths', () => {
  const allExist = () => true;
  const noneExist = () => false;

  it('returns an empty array if no dependencies are in load paths', () => {
    const alwaysFalse = () => false;
    const result = getDefaultLoadPaths(alwaysFalse, allExist);

    expect(result).to.deep.equal([]);
  });

  context('with the Login.gov Design System as a dependency', () => {
    const trueForLgds = (dependency) => dependency === '@18f/identity-design-system';

    it('prefers the packages-uswds overlay when present', () => {
      const result = getDefaultLoadPaths(trueForLgds, allExist);

      expect(result).to.deep.equal(['node_modules/@18f/identity-design-system/packages-uswds']);
    });

    it('falls back to the legacy packages overlay when packages-uswds is absent', () => {
      const result = getDefaultLoadPaths(trueForLgds, noneExist);

      expect(result).to.deep.equal(['node_modules/@18f/identity-design-system/packages']);
    });
  });

  context('with the U.S. Web Design System as a dependency', () => {
    it('returns load paths for the U.S. Web Design System', () => {
      const trueForUswds = (dependency) => dependency === '@uswds/uswds';
      const result = getDefaultLoadPaths(trueForUswds, allExist);

      expect(result).to.deep.equal(['node_modules/@uswds/uswds/packages']);
    });
  });
});
