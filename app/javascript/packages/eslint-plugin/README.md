# `@18f/eslint-plugin-identity`

ESLint plugin and shareable configurations for Login.gov JavaScript standards.

These configurations largely inherit from the [TTS JavaScript coding standards](https://engineering.18f.gov/javascript/#style), pre-bundled with recommended rulesets and extended to provide support for Login.gov-specific implementation choices (React, Mocha, TypeScript).

## Installation

Install using [NPM](https://www.npmjs.com/) or [Yarn](https://yarnpkg.com/). [ESLint](https://eslint.org/) and `eslint-plugin-import` are required as peer dependencies and should be installed if it is not already.

```
npm install --save-dev @18f/eslint-plugin-identity eslint eslint-plugin-import
```

The configuration automatically includes additional behavior if any of the following packages are installed in your project:

- If `eslint-plugin-mocha` is installed, the Mocha environment and Mocha-specific rules are enabled.
- If `eslint-plugin-react`, `eslint-plugin-jsx-a11y`, and `eslint-plugin-react-hooks` are installed, JSX and React rules are enabled.
- If `eslint-plugin-prettier` is installed, Prettier rules are enabled.
- If `@typescript-eslint/parser` and `@typescript-eslint/eslint-plugin` are installed, TypeScript rules are enabled.

## Usage

Currently, one configuration is made available for use: the `recommended` ruleset.

Because the module is published as an ESLint plugin, you should configure it as both a `plugins` and an `extends` in your [ESLint configuration](https://eslint.org/docs/user-guide/configuring/):

```json
{
  "extends": ["plugin:@18f/eslint-plugin-identity/recommended"],
  "plugins": ["@18f/eslint-plugin-identity"]
}
```

## Frequently Asked Questions

### Why are the configurations published under an ESLint plugin?

Publishing the package as an ESLint plugin has the advantage of allowing for custom rules to be implemented and used within the same package as the configurations.

## License

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.
