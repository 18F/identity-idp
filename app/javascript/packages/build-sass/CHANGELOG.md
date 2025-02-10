## Unreleased

- Fix typecheck error due to updated arguments in `fileURLToPath` from `node:url`

## 3.1.0

### New Features

- Add support for verbose CLI output using `--verbose` flag (`-v` shorthand), which currently outputs files being built.

### Bug Fixes

- Fix rebuild after error when using `--watch` mode.

## 3.0.0

### Breaking Changes

- Requires Node.js v18 or newer

### Improvements

- `--out-dir` is now optional. If omitted, files will be output in the same directory as their source files.
- The command-line tool now uses [Sass Shared Resources API](https://github.com/sass/sass/blob/main/accepted/shared-resources.d.ts.md), improving performance when compiling multiple files that share common resources.
  - In Login.gov's identity provider application, this reduced compilation times by an average of 66%!

## 2.0.0

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
