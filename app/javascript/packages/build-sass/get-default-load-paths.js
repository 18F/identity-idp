import { isDependency } from '@aduth/is-dependency';

/** @type {Record<string, string[]>} */
const DEPENDENCY_LOAD_PATHS_MAPPING = {
  '@18f/identity-design-system': ['node_modules/@18f/identity-design-system/packages'],
  '@uswds/uswds': ['node_modules/@uswds/uswds/packages'],
};

/**
 * Returns an array of load paths which should be loaded by default based on supported dependencies.
 *
 * @return {string[]} Array of load paths.
 */
const getDefaultLoadPaths = () =>
  Object.entries(DEPENDENCY_LOAD_PATHS_MAPPING)
    .filter(([dependency]) => isDependency(dependency))
    .flatMap(([, loadPaths]) => loadPaths);

export default getDefaultLoadPaths;
