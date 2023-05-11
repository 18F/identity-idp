## Unreleased

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
