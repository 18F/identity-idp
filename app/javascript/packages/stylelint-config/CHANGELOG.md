## 3.0.0

### Breaking Changes

- Breaking changes included in updated dependencies:
  - [`stylelint-prettier`](https://github.com/prettier/stylelint-prettier/blob/main/CHANGELOG.md):
    - Dropped support for `prettier` versions below `v3.0.0`.
    - Dropped support for `stylelint` versions below `v15.8.0`.
  - [`stylelint-config-recommended-scss`](https://github.com/stylelint-scss/stylelint-config-recommended-scss/blob/master/CHANGELOG.md)
    - Dropped support for `stylelint` versions below `v15.10.0`.
  - [`stylelint-config-recommended`](https://github.com/stylelint/stylelint-config-recommended/blob/main/CHANGELOG.md)
    - Changed defaults may identify new issues in your existing code:
      - [`stylelint-config-recommended@13.0.0`](https://github.com/stylelint/stylelint-config-recommended/releases/tag/13.0.0) added `media-query-no-invalid`

## 2.0.0

### Breaking Changes

- Dropped support for Stylelint v14. You should [migrate to Stylelint v15](https://github.com/stylelint/stylelint/blob/main/docs/migration-guide/to-15.md) to use this new version.
- Breaking changes included in updated dependencies:
   - Node.js v12 is no longer supported as of [`stylelint-prettier@3.0.0`](https://github.com/prettier/stylelint-prettier/blob/main/CHANGELOG.md#300-2023-02-22)
   - The configuration enabled through [`stylelint-config-recommended`] includes a number of new defaults, which may identify new issues in your existing code:
      - [`stylelint-config-recommended@12.0.0`](https://github.com/stylelint/stylelint-config-recommended/releases/tag/12.0.0) changed `declaration-block-no-duplicate-properties`
      - [`stylelint-config-recommended@11.0.0`](https://github.com/stylelint/stylelint-config-recommended/releases/tag/11.0.0) added `selector-anb-no-unmatchable`
      - [`stylelint-config-recommended@9.0.0`](https://github.com/stylelint/stylelint-config-recommended/releases/tag/9.0.0) added `annotation-no-unknown`
      - [`stylelint-config-recommended@8.0.0`](https://github.com/stylelint/stylelint-config-recommended/releases/tag/8.0.0) added `keyframe-block-no-duplicate-selectors`
      - [`stylelint-config-recommended@7.0.0`](https://github.com/stylelint/stylelint-config-recommended/releases/tag/7.0.0) added `function-no-unknown`
      - [`stylelint-config-recommended@6.0.0`](https://github.com/stylelint/stylelint-config-recommended/releases/tag/6.0.0) added `custom-property-no-missing-var-function`

## 1.0.0

- Initial release
