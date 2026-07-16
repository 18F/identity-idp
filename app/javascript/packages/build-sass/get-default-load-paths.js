/** @type {Record<string, string[]>} */
const DEPENDENCY_LOAD_PATHS_MAPPING = {};

/**
 * Returns an array of load paths which should be loaded by default based on supported dependencies.
 *
 * @return {string[]} Array of load paths.
 */
const getDefaultLoadPaths = (isDependency) =>
  Object.entries(DEPENDENCY_LOAD_PATHS_MAPPING)
    .filter(([dependency]) => isDependency(dependency))
    .flatMap(([, loadPaths]) => loadPaths);

export default getDefaultLoadPaths;
