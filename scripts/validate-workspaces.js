#!/usr/bin/env node

const { readFile } = require('fs/promises');
const { dirname, basename } = require('path');
const { sync: glob } = require('fast-glob');

/** @typedef {[path: string, manifest: Record<string, any>]} ManifestPair */
/** @typedef {ManifestPair[]} ManifestPairs */

/**
 * @param {ManifestPairs} manifests
 */
function checkHaveNoDevDependencies(manifests) {
  for (const [path, manifest] of manifests) {
    if ('devDependencies' in manifest) {
      throw new Error(
        `Unexpected devDependencies in ${path}. Define devDependencies in root package.json.`,
      );
    }
  }
}

/**
 * @param {ManifestPairs} manifests
 */
function checkHaveCommonDependencyVersions(manifests) {
  const versions = {};
  for (const [path, manifest] of manifests) {
    for (const [dependency, version] of Object.entries(manifest.dependencies || {})) {
      if (versions[dependency] && versions[dependency] !== version) {
        throw new Error(
          `Inconsistent dependency version for ${dependency}@${version} in ${path}. Use a common dependency version across all workspace packages, preferring to update all to the latest version.`,
        );
      }

      versions[dependency] = version;
    }
  }
}

/**
 * @param {ManifestPairs} manifests
 */
function checkHaveRequiredFields(manifests) {
  for (const [path, manifest] of manifests) {
    ['name', 'version', 'private'].forEach((field) => {
      if (!(field in manifest)) {
        throw new Error(`Missing required field ${field} in ${path}`);
      }
    });
  }
}

/**
 * @param {ManifestPairs} manifests
 */
function checkHaveCorrectPackageName(manifests) {
  for (const [path, manifest] of manifests) {
    const folder = basename(dirname(path));
    const expected = `@18f/identity-${folder}`;
    if (manifest.name !== expected) {
      throw new Error(`Incorrect package name ${manifest.name} in ${path}. Expected ${expected}.`);
    }
  }
}

/**
 * @param {ManifestPairs} manifests
 */
function checkHaveCorrectVersion(manifests) {
  for (const [path, manifest] of manifests) {
    if (manifest.private && manifest.version !== '1.0.0') {
      throw new Error(`Incorrect package version ${manifest.version} in ${path}. Expected 1.0.0.`);
    }
  }
}

/**
 * @param {ManifestPairs} manifests
 */
function checkHaveNoSiblingDependencies(manifests) {
  for (const [path, manifest] of manifests) {
    for (const [dependency] of Object.entries(manifest.dependencies || {})) {
      if (
        dependency.startsWith('@18f/identity-') &&
        manifests.some(([, { name }]) => dependency === name)
      ) {
        throw new Error(
          `Unexpected sibling dependency ${dependency} in ${path}. It's unnecessary to define sibling workspace packages as dependencies.`,
        );
      }
    }
  }
}

/**
 * @type {Record<string, (manifests: ManifestPairs) => void>}
 */
const CHECKS = {
  checkHaveNoDevDependencies,
  checkHaveCommonDependencyVersions,
  checkHaveRequiredFields,
  checkHaveCorrectPackageName,
  checkHaveCorrectVersion,
  checkHaveNoSiblingDependencies,
};

/**
 * @type {Record<string, string[]>}
 */
const EXCEPTIONS = {
  checkHaveCorrectPackageName: ['app/javascript/packages/eslint-plugin/package.json'],
};

const manifestPaths = glob('app/javascript/packages/*/package.json');
Promise.all(manifestPaths.map(async (path) => [path, await readFile(path, 'utf-8')]))
  .then((contents) =>
    contents.map(([path, content]) => /** @type {ManifestPair} */ ([path, JSON.parse(content)])),
  )
  .then((manifests) => {
    for (const [checkName, check] of Object.entries(CHECKS)) {
      const checkedManifests = manifests.filter(([path]) => !EXCEPTIONS[checkName]?.includes(path));
      check(checkedManifests);
    }
  })
  .catch((error) => {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  });
