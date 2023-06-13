import quibble from 'quibble';
import sinon from 'sinon';

describe('getDefaultLoadPaths', () => {
  const isDependency = sinon.stub();

  /** @type {import('./get-default-load-paths').default} */
  let getDefaultLoadPaths;

  beforeEach(async () => {
    isDependency.reset();
    isDependency.returns(false);
    await quibble.esm('@aduth/is-dependency', { isDependency });
    getDefaultLoadPaths = (await import('./get-default-load-paths.js')).default;
  });

  afterEach(() => {
    quibble.reset();
  });

  it('returns an empty array', () => {
    const result = getDefaultLoadPaths();

    expect(result).to.deep.equal([]);
  });

  context('with the Login.gov Design System as a dependency', () => {
    beforeEach(() => {
      isDependency.withArgs('@18f/identity-design-system').returns(true);
    });

    it('returns load paths for the Login.gov Design System', () => {
      const result = getDefaultLoadPaths();

      expect(result).to.deep.equal(['node_modules/@18f/identity-design-system/packages']);
    });
  });

  context('with the U.S. Web Design System as a dependency', () => {
    beforeEach(() => {
      isDependency.withArgs('@uswds/uswds').returns(true);
    });

    it('returns load paths for the U.S. Web Design System', () => {
      const result = getDefaultLoadPaths();

      expect(result).to.deep.equal(['node_modules/@uswds/uswds/packages']);
    });
  });
});
