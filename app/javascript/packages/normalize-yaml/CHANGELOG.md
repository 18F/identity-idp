## Unreleased

### Breaking Changes

- The new punctuation formatter described in "New Features" is enabled by default, which may identify new existing issues in your YAML files.

### New Features

- Added new punctuation formatter to collapse multiple spaces to a single space.
- Added new option `--ignore-key-sort` to preserve ordering of keys.

## v2.0.0

### Breaking Changes

- `normalize` method now returns a `Promise`, resolving to a `string`
- `prettier` peer dependency now requires v3 or newer

## v1.0.0

- Initial release
