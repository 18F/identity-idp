## Unreleased

### Breaking Changes

- The ruleset now extends [`stylelint-config-standard-scss`](https://github.com/stylelint-scss/stylelint-config-standard-scss) instead of [`stylelint-config-recommended-scss`](https://github.com/stylelint-scss/stylelint-config-recommended-scss). This configures a number of additional rules which may identify existing issues in your code.
  - This is intended to bring the ruleset into closer alignment with the [TTS Engineering CSS Coding Standards](https://guides.18f.gov/engineering/languages-runtimes/css/), which recommends the "standard" Stylelint rules.
  - Many of these rules can be fixed automatically using [Stylelint's `--fix` option](https://stylelint.io/user-guide/options/#fix).
  - Some rules have been disabled to permit more flexibility in code arrangement, particularly rules affecting blank line enforcement with comments and Sass `@`-rules:
    - [`at-rule-empty-line-before`](https://stylelint.io/user-guide/rules/at-rule-empty-line-before/)
    - [`declaration-empty-line-before`](https://stylelint.io/user-guide/rules/declaration-empty-line-before/)
    - [`rule-empty-line-before`](https://stylelint.io/user-guide/rules/rule-empty-line-before/)
    - [`scss/dollar-variable-empty-line-before`](https://github.com/stylelint-scss/stylelint-scss/blob/master/src/rules/dollar-variable-empty-line-before/README.md)
    - [`scss/double-slash-comment-empty-line-before`](https://github.com/stylelint-scss/stylelint-scss/blob/master/src/rules/double-slash-comment-empty-line-before/README.md)
    - [`color-function-notation`](https://stylelint.io/user-guide/rules/color-function-notation/) (due to [Sass incompatibilities](https://github.com/sass/sass/issues/2831))
- The ruleset now configures [`"reportNeedlessDisables": true`](https://stylelint.io/user-guide/options/#reportneedlessdisables), which will report inline configuration that disables rules unnecessarily.
- The [`declaration-no-important`](https://stylelint.io/user-guide/rules/declaration-no-important/) rule is now enabled, which disallows `!important` in stylesheets.
  - `!important` is a sledgehammer solution which often causes more problems than it helps, and usually stems from misunderstandings of [CSS specificity](https://developer.mozilla.org/en-US/docs/Web/CSS/Specificity). See related ["Best practices" MDN documentation](https://developer.mozilla.org/en-US/docs/Web/CSS/important#best_practices).

## 4.1.0

### Improvements

- The `selector-class-pattern` configuration now specifies [`resolveNestedSelectors: true`](https://stylelint.io/user-guide/rules/selector-class-pattern/#resolvenestedselectors-true--false-default-false) to resolve nested selectors using `&` interpolation.

## 4.0.0

### Breaking Changes

- Breaking changes included in updated dependencies:
  - Dropped support for `stylelint` versions below `v16.0.2`.
  - Dropped support for Node.js versions below `v18.12.0`.
  - For full details, refer to release notes for affected dependencies:
    - [`stylelint-prettier`](https://github.com/prettier/stylelint-prettier/blob/main/CHANGELOG.md)
    - [`stylelint-config-recommended-scss`](https://github.com/stylelint-scss/stylelint-config-recommended-scss/blob/master/CHANGELOG.md)
    - [`stylelint-scss`](https://github.com/stylelint-scss/stylelint-scss/blob/master/CHANGELOG.md)
    - [`stylelint-config-recommended`](https://github.com/stylelint/stylelint-config-recommended/blob/main/CHANGELOG.md)

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
