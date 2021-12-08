# `@18f/identity-stylelint-config`

Stylelint shareable configuration for Login.gov CSS/SASS standards.

These configurations largely inherit from the [TTS CSS coding standards](https://engineering.18f.gov/css/), pre-bundled with recommended rulesets and extended to provide support for Login.gov-specific implementation choices.

## Installation

Install using [NPM](https://www.npmjs.com/) or [Yarn](https://yarnpkg.com/). [Stylelint](https://stylelint.io/) and [Prettier](https://prettier.io/) are required as peer dependencies and should be installed if it is not already.

```
npm install --save-dev @18f/identity-stylelint-config stylelint prettier
```

## Usage

Create a `.stylelintrc.json` configuration file in the root of your project and extend this configuration:

```json
{
  "extends": "@18f/identity-stylelint-config"
}
```

When you next [run stylelint](https://stylelint.io/user-guide/usage/cli), it will apply the configured rules.

## License

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.
