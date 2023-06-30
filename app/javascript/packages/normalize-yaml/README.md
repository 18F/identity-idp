# @18f/identity-normalize-yaml

Normalizes YAML files to ensure consistency and typographical quality:

- Alphabetizes keys.
- Applies improved punctuation.
  - Converts straight quotes `"` and `'` to smart quotes `“`, `”`, and `’`
  - Converts three dots `...` to ellipsis `…`
- Stylizes content using [Prettier](https://prettier.io/), respecting local project Prettier configuration.

## Installation

Install using npm or Yarn. To reduce conflicts with a project's own Prettier dependency version, you must install Prettier as a separate dependency if not already installed.

Using npm:

```
npm install @18f/identity-normalize-yaml prettier
```

Using Yarn:

```
yarn add @18f/identity-normalize-yaml prettier
```

## Usage

### CLI

The included `normalize-yaml` binary receives files as an argument, with optional flags:

- `--disable-sort-keys`: Disable the default behavior to sort keys.
- `--disable-smart-punctuation`: Disable the default behavior to apply smart punctuation.

**Example:**

Using npm:

```
npm exec normalize-yaml path/to/file.yml -- --disable-sort-keys
```

Using Yarn:

```
yarn normalize-yaml path/to/file.yml --disable-sort-keys
```

### API

#### `normalize(content: string, config?: Options): string`

Given an input YAML string and optional options, returns a normalized YAML string.

**Options:**

- `prettierConfig` (`Record<string, any>`): Optional Prettier configuration object.
- `exclude` (`Formatter[]`) Formatters to exclude.

## License

This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

All contributions to this project will be released under the CC0 dedication. By submitting a pull request or issue, you are agreeing to comply with this waiver of copyright interest.
