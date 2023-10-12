## Unreleased

### Breaking Changes

- Changed priority for how load paths are used when resolving modules. The net effect is that any `--load-path` should take highest priority over those provided as defaults.
  - Before: (1) `node_modules`, (2) default load paths, (3) custom `--load-path` load paths
  - After: (1) custom `--load-path` load paths, (2) default load paths, (3) `node_modules`

### Improvements

- Prevent situations where overridden output stylesheets may be temporarily emptied during parallel builds.

### Miscellaneous

- Update dependencies to latest versions.

## 1.3.0

### Improvements

- Adds support for ".scss" file extension, as an alternative to the current ".css.scss" support. In both cases, the output files use the basename with a ".css" extension.
- Creates the `--out-dir` directory if it does not exist already.
- Outputs any error that occurs during build, not just Sass compilation errors.

## 1.2.0

### Improvements

- Adds default load paths when a supported dependency is installed.
  - If `@18f/identity-design-system` is installed, `node_modules/@18f/identity-design-system/packages` is added as a load path.
  - If `@uswds/uswds` is installed, `node_modules/@uswds/uswds/packages` is added as a load path.

## 1.1.0

### Improvements

- Improves watch mode error recovery to monitor changes to all files in the stack trace of the error.
- Adds support for `--load-path=` flag to include additional default paths in Sass path resolution.

## 1.0.0

- Initial release
