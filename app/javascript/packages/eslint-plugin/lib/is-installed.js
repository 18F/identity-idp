const { join } = require('path');
const { readFileSync } = require('fs');

let cache;

/**
 * Returns true if the given dependency is installed to the local project, or false otherwise.
 *
 * @param {string} name Dependency name.
 *
 * @return {boolean} Whether dependency is installed.
 */
function isInstalled(name) {
  if (!cache) {
    cache = Object.create(null);
    try {
      const { dependencies, devDependencies } = JSON.parse(
        readFileSync(join(process.cwd(), 'package.json'), 'utf-8'),
      );
      cache = Object.assign(cache, dependencies, devDependencies);
    } catch {}
  }

  return !!cache[name];
}

module.exports = isInstalled;
