import getDefaultLoadPaths from './get-default-load-paths.js';

describe('getDefaultLoadPaths', () => {
  const overlayPathExists = () => true;
  const overlayPathMissing = () => false;

  it('returns an empty array if no dependencies are in load paths', () => {
    const isNotDependency = () => false;
    const result = getDefaultLoadPaths(isNotDependency, overlayPathExists);

    expect(result).to.deep.equal([]);
  });

  context('with the Login.gov Design System as a dependency', () => {
    const isLgdsDependency = (dependency) => dependency === '@18f/identity-design-system';

    it('prefers the packages-uswds overlay when present', () => {
      const result = getDefaultLoadPaths(isLgdsDependency, overlayPathExists);

      expect(result).to.deep.equal(['node_modules/@18f/identity-design-system/packages-uswds']);
    });

    it('falls back to the legacy packages overlay when packages-uswds is absent', () => {
      const result = getDefaultLoadPaths(isLgdsDependency, overlayPathMissing);

      expect(result).to.deep.equal(['node_modules/@18f/identity-design-system/packages']);
    });
  });

  context('with the U.S. Web Design System as a dependency', () => {
    it('returns load paths for the U.S. Web Design System', () => {
      const isUswdsDependency = (dependency) => dependency === '@uswds/uswds';
      const result = getDefaultLoadPaths(isUswdsDependency, overlayPathExists);

      expect(result).to.deep.equal(['node_modules/@uswds/uswds/packages']);
    });
  });
});
