import { existsSync } from 'node:fs';

const LGDS = '@18f/identity-design-system';

// The Login.gov Design System publishes its Sass overlay under
// `packages-uswds/`, keeping `packages/` as a back-compat alias. Prefer
// `packages-uswds/` and fall back to `packages/` for older versions. Exactly
// one root is returned: listing both would load (and re-configure) the shared
// `uswds-core` module twice, which Sass rejects.
const lgdsLoadPath = (pathExists) => {
  const lgdsUswdsOverlayPath = `node_modules/${LGDS}/packages-uswds`;
  const lgdsBackCompatPath = `node_modules/${LGDS}/packages`;
  return pathExists(lgdsUswdsOverlayPath) ? lgdsUswdsOverlayPath : lgdsBackCompatPath;
};

/**
 * Returns an array of load paths which should be loaded by default based on supported dependencies.
 *
 * @param {(dependency: string) => boolean} isDependency Whether a package is an installed dependency.
 * @param {(path: string) => boolean} [pathExists] Filesystem existence check (injectable for tests).
 * @return {string[]} Array of load paths.
 */
const getDefaultLoadPaths = (isDependency, pathExists = existsSync) => {
  const loadPaths = [];

  if (isDependency(LGDS)) {
    loadPaths.push(lgdsLoadPath(pathExists));
  }

  if (isDependency('@uswds/uswds')) {
    loadPaths.push('node_modules/@uswds/uswds/packages');
  }

  return loadPaths;
};

export default getDefaultLoadPaths;
