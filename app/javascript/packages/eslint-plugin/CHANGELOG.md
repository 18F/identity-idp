## Unreleased

### Backwards-compatible changes

- Disabled many stylistic rules which would be redundant with Prettier formatting. For stylistic enforcement, it's recommended to opt-in to the optional Prettier rule extension.
  - `array-bracket-spacing`
  - `arrow-parens`
  - `arrow-spacing`
  - `block-spacing`
  - `brace-style`
  - `comma-spacing`
  - `comma-style`
  - `computed-property-spacing`
  - `dot-location`
  - `func-call-spacing`
  - `function-call-argument-newline`
  - `generator-star-spacing`
  - `jsx-quotes`
  - `key-spacing`
  - `keyword-spacing`
  - `no-extra-semi`
  - `no-tabs`
  - `no-trailing-spaces`
  - `object-curly-spacing`
  - `padded-blocks`
  - `quote-props`
  - `rest-spread-spacing`
  - `semi`
  - `semi-spacing`
  - `semi-style`
  - `space-before-function-paren`
  - `space-in-parens`
  - `switch-colon-spacing`
  - `template-curly-spacing`
  - `template-tag-spacing`
  - `yield-star-spacing`
- TypeScript: More default ESLint rules have been substituted with TypeScript-enhanced versions:
  - `default-param-last`
  - `lines-between-class-members`
  - `no-array-constructor`
  - `no-dupe-class-members`
  - `no-empty-function`
  - `no-loop-func`
  - `no-loss-of-precision`
  - `no-redeclare`
  - `no-useless-constructor`
- React: The following rules are no longer enforced:
  - `react/no-array-index-key`

## v2.0.0 (2022-03-14)

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
