## v2.0.0 (Unreleased)

### Breaking changes

- Updated peer dependencies to require ESLint >= 8 ([see migration guide](https://eslint.org/docs/8.0.0/user-guide/migrating-to-8.0.0)).
- Updated base Airbnb shared configurations, introducing newly-enforced rules (see [`airbnb` changelog](https://github.com/airbnb/javascript/blob/master/packages/eslint-config-airbnb/CHANGELOG.md), [`airbnb-base` changelog](https://github.com/airbnb/javascript/blob/master/packages/eslint-config-airbnb-base/CHANGELOG.md)).
- Removed Babel auto-configuration. As an alternative, consider [configuring ESLint to use modern syntax and/or JSX](https://eslint.org/docs/user-guide/configuring/language-options#specifying-parser-options), or use the new TypeScript configuration.
- Automatic opt-in behavior has changed and now requires you to install the requisite peer dependencies to your project. Refer to README.md for details.

### New features

- Added new TypeScript opt-in automatic configuration.

### Backwards-compatible changes

- `no-cond-assign` is now configured with the [`except-parens` option](https://eslint.org/docs/rules/no-cond-assign#except-parens).

## v1.0.0 (2021-09-03)

- Initial release
