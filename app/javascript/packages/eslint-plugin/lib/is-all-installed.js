const { join } = require('path');
const { readFileSync } = require('fs');

let cache;

/**
 * Returns true if all of the given dependencies are installed to the local project, or false
 * otherwise.
 *
 * @param {string[]} names Dependency names.
 *
 * @return {boolean} Whether dependencies are installed.
 */
function isAllInstalled(names) {
  if (!cache) {
    cache = Object.create(null);
    try {
      const { dependencies, devDependencies } = JSON.parse(
        readFileSync(join(process.cwd(), 'package.json'), 'utf-8'),
      );
      cache = Object.assign(cache, dependencies, devDependencies);
    } catch {}
  }

  return names.every((name) => !!cache[name]);
}

module.exports = isAllInstalled;
