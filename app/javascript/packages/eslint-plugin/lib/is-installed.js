const { join } = require('path');
const { readFileSync } = require('fs');

let cache;

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
